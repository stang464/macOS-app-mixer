#include "../AppMixer/AudioKernel.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

typedef struct { UInt32 count; AudioBuffer buffers[3]; } BufferList;
int main(void) {
    float stereo[] = {0.8f, -0.4f, 0.2f, 0.6f};
    float output[4] = {9,9,9,9};
    BufferList in = {1, {{2, sizeof(stereo), stereo}}};
    BufferList out = {1, {{2, sizeof(output), output}}};
    MixerKernel *k = MixerKernelCreate(0.5f, 48000, 2);
    MixerKernelRender(k, (AudioBufferList *)&in, (AudioBufferList *)&out);
    assert(fabsf(output[0]-0.4f)<1e-6 && fabsf(output[1]+0.2f)<1e-6);
    assert(fabsf(output[2]-0.1f)<1e-6 && fabsf(output[3]-0.3f)<1e-6);
    assert(MixerKernelCycles(k)==1);
    // A 10ms ramp reaches mute without a sudden jump.
    MixerKernelSetGain(k, 0);
    for (int n=0;n<300;n++) MixerKernelRender(k,(AudioBufferList *)&in,(AudioBufferList *)&out);
    assert(output[0]==0 && output[1]==0);
    MixerKernelDestroy(k);
    // Hardware input must never be mistaken for the appended process tap.
    float hardware[] = {99,99}, left[] = {0.7f,0.5f}, right[] = {-0.3f,-0.1f};
    float outL[2], outR[2];
    in = (BufferList){3, {{1,sizeof(hardware),hardware},{1,sizeof(left),left},{1,sizeof(right),right}}};
    out = (BufferList){2, {{1,sizeof(outL),outL},{1,sizeof(outR),outR}}};
    k = MixerKernelCreate(1,48000,2);
    MixerKernelRender(k,(AudioBufferList *)&in,(AudioBufferList *)&out);
    assert(outL[0]==0.7f && outR[0]==-0.3f && outR[1]==-0.1f);
    // Mono destination gets the stereo average.
    out = (BufferList){1, {{1,sizeof(outL),outL}}};
    MixerKernelRender(k,(AudioBufferList *)&in,(AudioBufferList *)&out);
    assert(fabsf(outL[0]-0.2f)<1e-6);
    // Missing input is silence, and never an out-of-bounds read.
    in.buffers[1].mData = NULL;
    in.buffers[2].mDataByteSize = 0;
    MixerKernelRender(k,(AudioBufferList *)&in,(AudioBufferList *)&out);
    assert(outL[0]==0 && outL[1]==0);
    MixerKernelDestroy(k);
    puts("PASS: attenuation, mute ramp, planar/interleaved stereo, hardware-input exclusion, mono, missing data");
}
