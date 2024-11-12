const pa = @cImport({
    @cInclude("portaudio.h");
});

const fftw = @cImport({
    @cInclude("fftw3.h");
});

const std = @import("std");

pub fn main() !void {
    // const allocator = std.heap.page_allocator;

    if (pa.Pa_Initialize() != pa.paNoError) {
        std.debug.print("Failed to initialize PortAudio!\n", .{});
        return;
    }

    std.debug.print("List of audio devices:\n", .{});
    const numDevices = pa.Pa_GetDeviceCount();
    for (0..@intCast(numDevices)) |i| {
        const deviceInfo = pa.Pa_GetDeviceInfo(@intCast(i));
        if (deviceInfo != null and deviceInfo.*.maxInputChannels > 0) {
            std.debug.print("\tDevice {d}: {s} ({d} channels)\n", .{ i, deviceInfo.*.name, deviceInfo.*.maxInputChannels });
        }
    }

    const device: c_int = pa.Pa_GetDefaultInputDevice();
    const deviceInfo = pa.Pa_GetDeviceInfo(device);
    std.debug.print("\nChosen device is: {s}.\n\n", .{deviceInfo.*.name});

    const inputParameters = pa.struct_PaStreamParameters{
        .device = device,
        .channelCount = 1,
        .sampleFormat = pa.paFloat32,
        .suggestedLatency = deviceInfo.*.defaultLowInputLatency,
        .hostApiSpecificStreamInfo = null,
    };

    var sampleRate: f64 = undefined;

    const sampleRates = [_]f64{ 8000, 16000, 32000, 44100, 48000, 96000 };
    for (sampleRates) |rate| {
        const result = pa.Pa_IsFormatSupported(&inputParameters, null, rate);
        if (result == pa.paFormatIsSupported) {
            std.debug.print("Sample rate {d} Hz is supported\n", .{rate});
            sampleRate = rate;
        } else {
            std.debug.print("Sample rate {d} Hz is NOT supported\n", .{rate});
        }
    }

    if (sampleRate == undefined) {
        std.debug.print("No supported sample rates found!\n", .{});
        return;
    }

    var stream: ?*pa.PaStream = null;
    const streamInitError = pa.Pa_OpenStream(&stream, &inputParameters, null, sampleRate, 256, pa.paClipOff, null, null);
    if (streamInitError != pa.paNoError) {
        std.debug.print("Failed to open stream: {s}\n", .{pa.Pa_GetErrorText(streamInitError)});
        return;
    }

    var buffer: [256]f32 = undefined;

    std.debug.print("Listening for audio input...\n", .{});
    const streamStartError = pa.Pa_StartStream(stream);
    if (streamInitError != pa.paNoError) {
        std.debug.print("Failed to start stream: {s}\n", .{pa.Pa_GetErrorText(streamStartError)});
        return;
    }

    while (true) {
        const streamReadError = pa.Pa_ReadStream(stream, &buffer, buffer.len);
        if (streamReadError != pa.paNoError) {
            std.debug.print("Failed to read audio stream: {s}\n", .{pa.Pa_GetErrorText(streamReadError)});
            std.debug.print("{s}\n", .{pa.Pa_GetLastHostErrorInfo().*.errorText});
            break;
        }

        // Calculate the frequency (for now, just a placeholder)
        const frequency: f32 = calculateFrequency(buffer[0..]);
        std.debug.print("Detected frequency: {d} Hz\n", .{frequency});
    }

    _ = pa.Pa_StopStream(stream);
    _ = pa.Pa_CloseStream(stream);
    _ = pa.Pa_Terminate();
}

fn calculateFrequency(samples: []const f32) f32 {
    const N: u16 = 256;
    var input: [N]f64 = undefined;
    var output: [N]f64 = undefined;

    for (samples, 0..) |sample, i| {
        input[i] = @floatCast(sample);
    }

    // Allocate FFTW resources
    const plan = fftw.fftw_plan_r2r_1d(N, &input[0], &output[0], fftw.FFTW_R2HC, fftw.FFTW_ESTIMATE);
    fftw.fftw_execute(plan);
    fftw.fftw_destroy_plan(plan);

    // Find the frequency with the maximum amplitude
    var maxAmplitude: f64 = 0;
    var dominantFrequency: f32 = 0;
    const sampleRate: f32 = 44100.0;

    for (0..N / 2) |i| {
        const amplitude = output[i] * output[i];
        if (amplitude > maxAmplitude) {
            maxAmplitude = amplitude;
            dominantFrequency = @floatFromInt(i);
        }
    }

    // Calculate the frequency in Hz
    return @floatCast((dominantFrequency * sampleRate) / N);
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
