const pa = @cImport({
    @cInclude("portaudio.h");
});

const std = @import("std");
const cli = @import("cli.zig");
const analyzer = @import("analyzer.zig");

pub fn main() !void {
    std.debug.print("[INFO]: initializing GuitarZ.\n", .{});
    if (!cli.parseArguments()) {
        return;
    }

    if (cli.sample_rate != null) {
        std.debug.print("[INFO]: user-chosen sample rate is: {any}.\n", .{cli.sample_rate});
    }

    //var preferred_device: u32 = undefined;
    const sampleRates = [_]f64{ 8000, 16000, 32000, 44100, 48000, 96000 };
    const bufferSize = 4196 * 4;

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

    const sampleRate: f64 = for (sampleRates) |rate| {
        const result = pa.Pa_IsFormatSupported(&inputParameters, null, rate);
        if (result == pa.paFormatIsSupported) {
            std.debug.print("Sample rate {d} Hz is supported\n", .{rate});
            break rate;
        } else {
            std.debug.print("Sample rate {d} Hz is NOT supported\n", .{rate});
        }
    } else {
        std.debug.print("No supported sample rates found!\n", .{});
        return;
    };

    std.debug.print("Chosen sample rate is {d}.\n", .{sampleRate});

    std.debug.print("Buffer size is {d}.\n\n", .{bufferSize});

    var stream: ?*pa.PaStream = null;
    const streamInitError = pa.Pa_OpenStream(&stream, &inputParameters, null, sampleRate, bufferSize, pa.paClipOff, null, null);
    if (streamInitError != pa.paNoError) {
        std.debug.print("Failed to open stream: {s}\n", .{pa.Pa_GetErrorText(streamInitError)});
        return;
    }

    var buffer: [bufferSize]f32 = undefined;

    std.debug.print("Listening for audio input...\n", .{});
    const streamStartError = pa.Pa_StartStream(stream);
    if (streamInitError != pa.paNoError) {
        std.debug.print("Failed to start stream: {s}\n", .{pa.Pa_GetErrorText(streamStartError)});
        return;
    }

    std.debug.print("x1B[2J\x1B[H", .{});

    while (true) {
        const streamReadError = pa.Pa_ReadStream(stream, &buffer, buffer.len);
        if (streamReadError != pa.paNoError) {
            std.debug.print("Failed to read audio stream: {s}\n", .{pa.Pa_GetErrorText(streamReadError)});
            std.debug.print("{s}\n", .{pa.Pa_GetLastHostErrorInfo().*.errorText});
            break;
        }

        _ = analyzer.recognizeNote(buffer[0..], bufferSize, sampleRate);

        //std.debug.print("\x1B[2J\x1B[HDetected note: {s}.\n", .{analyzer.recognizeNote(buffer[0..], bufferSize, sampleRate)});
        //const frequency: f32 = calculateFrequency(buffer[0..], bufferSize, sampleRate);
        //std.debug.print("{}", .{frequency});
        //std.debug.print("\x1B[2J\x1B[HDetected frequency: {d} Hz\n", .{frequency});
        //std.time.sleep(100_000_000);
    }

    _ = pa.Pa_StopStream(stream);
    _ = pa.Pa_CloseStream(stream);
    _ = pa.Pa_Terminate();
}
