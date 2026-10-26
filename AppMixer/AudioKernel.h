#pragma once
#include <CoreAudio/CoreAudio.h>
#include <stdint.h>

typedef struct MixerKernel MixerKernel;
MixerKernel * _Nullable MixerKernelCreate(float gain, double sampleRate, uint32_t tapChannels);
void MixerKernelDestroy(MixerKernel * _Nonnull kernel);
void MixerKernelSetGain(MixerKernel * _Nonnull kernel, float gain);
float MixerKernelPeak(MixerKernel * _Nonnull kernel);
uint64_t MixerKernelCycles(MixerKernel * _Nonnull kernel);
void MixerKernelRender(MixerKernel * _Nonnull kernel, const AudioBufferList * _Nonnull input, AudioBufferList * _Nonnull output);
OSStatus MixerIOProc(AudioObjectID device, const AudioTimeStamp * _Nonnull now,
                    const AudioBufferList * _Nonnull input, const AudioTimeStamp * _Nonnull inputTime,
                    AudioBufferList * _Nonnull output, const AudioTimeStamp * _Nonnull outputTime, void * _Nullable context);

// Non-realtime helper for identifying an audio process whose app metadata is unavailable.
int MixerProcessPath(pid_t pid, char * _Nonnull buffer, uint32_t bufferSize);
