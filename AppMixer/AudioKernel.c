#include "AudioKernel.h"
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

struct MixerKernel {
    _Atomic(float) target;
    _Atomic(float) peak;
    _Atomic(uint64_t) cycles;
    float current;
    float step;
    uint32_t tapChannels;
};

MixerKernel *MixerKernelCreate(float gain, double sampleRate, uint32_t channels) {
    MixerKernel *k = calloc(1, sizeof(*k));
    if (!k) return NULL;
    atomic_init(&k->target, gain);
    atomic_init(&k->peak, 0);
    atomic_init(&k->cycles, 0);
    k->current = gain;
    k->step = 1.0f / (float)(sampleRate * 0.01);
    k->tapChannels = channels;
    return k;
}
void MixerKernelDestroy(MixerKernel *k) { free(k); }
void MixerKernelSetGain(MixerKernel *k, float g) { atomic_store_explicit(&k->target, fminf(1, fmaxf(0, g)), memory_order_relaxed); }
float MixerKernelPeak(MixerKernel *k) { return atomic_load_explicit(&k->peak, memory_order_relaxed); }
uint64_t MixerKernelCycles(MixerKernel *k) { return atomic_load_explicit(&k->cycles, memory_order_relaxed); }

// Tap channels are appended after any hardware input channels in the aggregate.
// No allocation, locks, Swift calls or property queries on the audio thread.
static float sample(const AudioBufferList *list, uint32_t channel, uint32_t frame) {
    for (uint32_t b = 0; b < list->mNumberBuffers; ++b) {
        const AudioBuffer *buffer = &list->mBuffers[b];
        if (channel < buffer->mNumberChannels) {
            uint32_t offset = frame * buffer->mNumberChannels + channel;
            if (!buffer->mData || (offset + 1) * sizeof(float) > buffer->mDataByteSize) return 0;
            return ((const float *)buffer->mData)[offset];
        }
        channel -= buffer->mNumberChannels;
    }
    return 0;
}
void MixerKernelRender(MixerKernel *k, const AudioBufferList *in, AudioBufferList *out) {
    uint32_t inChannels = 0, outChannels = 0, frames = UINT32_MAX;
    for (uint32_t b = 0; b < in->mNumberBuffers; ++b) inChannels += in->mBuffers[b].mNumberChannels;
    for (uint32_t b = 0; b < out->mNumberBuffers; ++b) {
        AudioBuffer *buffer = &out->mBuffers[b];
        if (buffer->mData) memset(buffer->mData, 0, buffer->mDataByteSize);
        outChannels += buffer->mNumberChannels;
        if (buffer->mNumberChannels && buffer->mData) {
            uint32_t n = buffer->mDataByteSize / (sizeof(float) * buffer->mNumberChannels);
            if (n < frames) frames = n;
        }
    }
    if (!outChannels || inChannels < k->tapChannels || frames == UINT32_MAX) return;
    uint32_t first = inChannels - k->tapChannels;
    float target = atomic_load_explicit(&k->target, memory_order_relaxed), peak = 0;
    for (uint32_t f = 0; f < frames; ++f) {
        float diff = target - k->current;
        k->current += fmaxf(-k->step, fminf(k->step, diff));
        float left = sample(in, first, f);
        float right = k->tapChannels > 1 ? sample(in, first + 1, f) : left;
        uint32_t channel = 0;
        for (uint32_t b = 0; b < out->mNumberBuffers; ++b) {
            AudioBuffer *buffer = &out->mBuffers[b];
            for (uint32_t c = 0; c < buffer->mNumberChannels; ++c, ++channel) {
                float value = 0;
                if (outChannels == 1) value = (left + right) * 0.5f;
                else if (channel < 2) value = channel == 0 ? left : right;
                value *= k->current;
                if (buffer->mData) ((float *)buffer->mData)[f * buffer->mNumberChannels + c] = value;
                peak = fmaxf(peak, fabsf(value));
            }
        }
    }
    atomic_store_explicit(&k->peak, peak, memory_order_relaxed);
    atomic_fetch_add_explicit(&k->cycles, 1, memory_order_relaxed);
}
OSStatus MixerIOProc(AudioObjectID device, const AudioTimeStamp *now,
                    const AudioBufferList *input, const AudioTimeStamp *inputTime,
                    AudioBufferList *output, const AudioTimeStamp *outputTime, void *context) {
    MixerKernelRender(context, input, output);
    return noErr;
}

#include <libproc.h>
int MixerProcessPath(pid_t pid, char *buffer, uint32_t bufferSize) {
    return proc_pidpath(pid, buffer, bufferSize);
}
