const std = @import("std");

const c = @cImport({
    @cInclude("aubio/aubio.h");
});

const Note = struct { name: []const u8, frequency: f32 };

fn generateGuitarNotes() [6][25]Note {
    const NOTE_NAMES = [_][]const u8{
        "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B",
    };

    const BASE_NOTES = [_]Note{
        .{ .name = "E", .frequency = 82.41 },
        .{ .name = "A", .frequency = 110.00 },
        .{ .name = "D", .frequency = 146.83 },
        .{ .name = "G", .frequency = 196.00 },
        .{ .name = "B", .frequency = 246.94 },
        .{ .name = "E", .frequency = 329.63 },
    };

    const NUM_FRETS = 24;
    var notes: [6][25]Note = undefined;

    inline for (BASE_NOTES, 0..) |base_note, string_index| {
        var current_frequency = base_note.frequency;
        var current_note_index = findNoteIndex(base_note.name, &NOTE_NAMES);

        inline for (0..NUM_FRETS + 1) |fret| {
            notes[string_index][fret] = .{
                .name = NOTE_NAMES[current_note_index],
                .frequency = current_frequency,
            };

            // Move to the next semitone
            current_note_index = (current_note_index + 1) % 12;
            current_frequency *= std.math.pow(f32, 2.0, 1.0 / 12.0); // Frequency formula
        }
    }

    return notes;
}

fn findNoteIndex(comptime note: []const u8, comptime NOTE_NAMES: []const []const u8) u8 {
    inline for (NOTE_NAMES, 0..) |name, i| {
        if (std.mem.eql(u8, name, note)) {
            return @intCast(i);
        }
    }
    @panic("Invalid note name");
}

pub fn recognizeNote(input_buffer: []const f32, buffer_size: u16, sample_rate: f64) void { //*const [:0]u8 {
    const frequency: f32 = calculateFrequency(input_buffer, buffer_size, sample_rate);
    std.debug.print("\x1B[2J\x1B[HDetected frequency: {d}.\n", .{frequency});

    // const notes = generateGuitarNotes();

    // for (notes, 0..) |string, string_index| {
    //     std.debug.print("String {d}:\n", .{string_index + 1});
    //     for (string) |note| {
    //         std.debug.print("  {s}: {d} Hz\n", .{ note.name, note.frequency });
    //     }
    // }
}

pub fn calculateFrequency(input_buffer: []const f32, buffer_size: u16, sample_rate: f64) f32 {
    const hop_size = buffer_size / 2; // Number of samples per analysis step

    // Create Aubio pitch detection object
    const pitch_detection = c.new_aubio_pitch("default", buffer_size, hop_size, @intFromFloat(sample_rate));

    if (pitch_detection == null) {
        std.debug.print("Failed to initialize Aubio pitch detection\n", .{});
        return 0.0;
    }

    // Configure the pitch detection object
    _ = c.aubio_pitch_set_unit(pitch_detection, "Hz");
    _ = c.aubio_pitch_set_silence(pitch_detection, -90.0); // Silence threshold (adjustable)

    // Create Aubio input and output vectors
    const input_vector = c.new_fvec(buffer_size);
    const pitch_output = c.new_fvec(1);

    // Fill the Aubio input vector with the input audio data (up to buffer_size samples)
    for (input_buffer[0..buffer_size], 0..) |sample, i| {
        input_vector.*.data[i] = sample;
    }

    // Perform pitch detection
    c.aubio_pitch_do(pitch_detection, input_vector, pitch_output);

    // Retrieve the detected frequency
    const detected_frequency: f32 = pitch_output.*.data[0]; //@floatFromInt(pitch_output.*.data[0]);

    // Clean up Aubio objects
    c.del_aubio_pitch(pitch_detection);
    c.del_fvec(input_vector);
    c.del_fvec(pitch_output);

    return detected_frequency;
}
