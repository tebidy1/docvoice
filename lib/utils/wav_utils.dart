import 'dart:typed_data';

class WavUtils {
  static Uint8List addWavHeader(Uint8List pcmData, int sampleRate, int channels) {
    var header = ByteData(44);
    var totalDataLen = pcmData.length;
    var totalLength = totalDataLen + 36;
    var byteRate = sampleRate * channels * 2; // 16 bit = 2 bytes

    // RIFF chunk
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, totalLength, Endian.little);
    header.setUint8(8, 0x57); // 'W'
    header.setUint8(9, 0x41); // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'

    // fmt chunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6d); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // Length of fmt chunk
    header.setUint16(20, 1, Endian.little); // Audio format (1 = PCM)
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, channels * 2, Endian.little); // Block align
    header.setUint16(34, 16, Endian.little); // Bits per sample

    // data chunk
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, totalDataLen, Endian.little);

    var wavFile = Uint8List(44 + totalDataLen);
    wavFile.setRange(0, 44, header.buffer.asUint8List());
    wavFile.setRange(44, 44 + totalDataLen, pcmData);

    return wavFile;
  }
}
