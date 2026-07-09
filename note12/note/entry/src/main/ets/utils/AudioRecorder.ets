// entry/src/main/ets/utils/AudioRecorder.ets

import audio from '@ohos.multimedia.audio'
import fs from '@ohos.file.fs'

export interface AudioRecordResult {
  filePath: string
  duration: number
  fileSize: number
}

export class AudioRecorder {
  private audioCapturer: audio.AudioCapturer | null = null
  private isRecording: boolean = false
  private startTime: number = 0
  private pcmFilePath: string = ''
  private wavFilePath: string = ''
  private fileSize: number = 0
  private isStopped: boolean = false
  private context: Context
  private recordingPromise: Promise<void> | null = null

  constructor(context: Context) {
    this.context = context
  }

  async startRecording(): Promise<string> {
    try {
      const audioCapturerOptions: audio.AudioCapturerOptions = {
        streamInfo: {
          samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
          channels: audio.AudioChannel.CHANNEL_1,
          sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
          encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
        },
        capturerInfo: {
          source: audio.SourceType.SOURCE_TYPE_MIC,
          capturerFlags: 0
        }
      }

      this.audioCapturer = await audio.createAudioCapturer(audioCapturerOptions)

      if (!this.audioCapturer) {
        throw new Error('创建 AudioCapturer 失败')
      }

      const timestamp = Date.now()
      const fileDir = `${this.context.filesDir}/recordings`

      try {
        fs.mkdirSync(fileDir, true)
      } catch (e) {}

      this.pcmFilePath = `${fileDir}/recording_${timestamp}.pcm`
      this.wavFilePath = `${fileDir}/recording_${timestamp}.wav`

      await this.audioCapturer.start()
      this.isRecording = true
      this.isStopped = false
      this.startTime = Date.now()
      this.fileSize = 0

      // 启动录制循环
      this.recordingPromise = this.doRecording()

      return this.wavFilePath
    } catch (e) {
      console.error('startRecording error:', e)
      throw new Error('录音启动失败')
    }
  }

  private async doRecording(): Promise<void> {
    if (!this.audioCapturer || !this.isRecording) return

    const bufferSize = 4096

    try {
      const file = fs.openSync(this.pcmFilePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)

      while (this.isRecording && this.audioCapturer && !this.isStopped) {
        try {
          const data = await this.audioCapturer.read(bufferSize, true) as ArrayBuffer
          const readLength = data.byteLength

          if (readLength > 0) {
            fs.writeSync(file.fd, data)
            this.fileSize += readLength
          } else {
            await this.sleep(10)
          }
        } catch (e) {
          if (this.isRecording) {
            console.error('Recording error:', e)
          }
          break
        }
      }

      fs.closeSync(file.fd)
    } catch (e) {
      console.error('doRecording error:', e)
    }
  }

  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms))
  }

  private pcmToWav(pcmPath: string, wavPath: string, sampleRate: number, channels: number, bitsPerSample: number): void {
    const pcmFile = fs.openSync(pcmPath, fs.OpenMode.READ_ONLY)
    const pcmStat = fs.statSync(pcmPath)
    const dataSize = pcmStat.size

    // 读取 PCM 数据
    const pcmData = new ArrayBuffer(dataSize)
    fs.readSync(pcmFile.fd, pcmData)
    fs.closeSync(pcmFile.fd)

    // 计算 WAV 文件头各字段
    const byteRate = sampleRate * channels * bitsPerSample / 8
    const blockAlign = channels * bitsPerSample / 8
    const chunkSize = 36 + dataSize

    // 创建 WAV 文件头 (44 字节)
    const header = new ArrayBuffer(44)
    const view = new DataView(header)

    // ChunkID: "RIFF"
    view.setUint8(0, 0x52) // 'R'
    view.setUint8(1, 0x49) // 'I'
    view.setUint8(2, 0x46) // 'F'
    view.setUint8(3, 0x46) // 'F'

    // ChunkSize
    view.setUint32(4, chunkSize, true)

    // Format: "WAVE"
    view.setUint8(8, 0x57)  // 'W'
    view.setUint8(9, 0x41)  // 'A'
    view.setUint8(10, 0x56) // 'V'
    view.setUint8(11, 0x45) // 'E'

    // Subchunk1ID: "fmt "
    view.setUint8(12, 0x66) // 'f'
    view.setUint8(13, 0x6D) // 'm'
    view.setUint8(14, 0x74) // 't'
    view.setUint8(15, 0x20) // ' '

    // Subchunk1Size: 16 (PCM)
    view.setUint32(16, 16, true)

    // AudioFormat: 1 (PCM)
    view.setUint16(20, 1, true)

    // NumChannels
    view.setUint16(22, channels, true)

    // SampleRate
    view.setUint32(24, sampleRate, true)

    // ByteRate
    view.setUint32(28, byteRate, true)

    // BlockAlign
    view.setUint16(32, blockAlign, true)

    // BitsPerSample
    view.setUint16(34, bitsPerSample, true)

    // Subchunk2ID: "data"
    view.setUint8(36, 0x64) // 'd'
    view.setUint8(37, 0x61) // 'a'
    view.setUint8(38, 0x74) // 't'
    view.setUint8(39, 0x61) // 'a'

    // Subchunk2Size
    view.setUint32(40, dataSize, true)

    // 写入 WAV 文件
    const wavFile = fs.openSync(wavPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
    fs.writeSync(wavFile.fd, header)
    fs.writeSync(wavFile.fd, pcmData)
    fs.closeSync(wavFile.fd)

    // 删除临时 PCM 文件
    try {
      fs.unlinkSync(pcmPath)
    } catch (e) {}
  }

  async stopRecording(): Promise<AudioRecordResult> {
    if (!this.audioCapturer || !this.isRecording) {
      throw new Error('没有正在进行的录音')
    }

    try {
      this.isRecording = false
      this.isStopped = true

      // 等待录制循环结束
      if (this.recordingPromise) {
        await this.recordingPromise
      }

      await this.audioCapturer.stop()
      await this.audioCapturer.release()
      this.audioCapturer = null

      const duration = Date.now() - this.startTime

      // PCM 转 WAV
      try {
        this.pcmToWav(this.pcmFilePath, this.wavFilePath, 16000, 1, 16)
      } catch (e) {
        console.error('PCM to WAV failed:', e)
        // 如果转换失败，返回 PCM 文件路径
        this.wavFilePath = this.pcmFilePath
      }

      // 重新获取 WAV 文件大小
      try {
        const stat = fs.statSync(this.wavFilePath)
        this.fileSize = stat.size
      } catch (e) {}

      return {
        filePath: this.wavFilePath,
        duration: duration,
        fileSize: this.fileSize
      }
    } catch (e) {
      console.error('Stop recording failed:', e)
      throw new Error('停止录音失败')
    }
  }

  async cancelRecording(): Promise<void> {
    this.isRecording = false
    this.isStopped = true

    // 等待录制循环结束
    if (this.recordingPromise) {
      try {
        await this.recordingPromise
      } catch (e) {}
    }

    if (this.audioCapturer) {
      try {
        await this.audioCapturer.stop()
        await this.audioCapturer.release()
      } catch (e) {}
      this.audioCapturer = null
    }

    // 删除临时文件
    try {
      if (this.pcmFilePath) {
        fs.unlinkSync(this.pcmFilePath)
      }
    } catch (e) {}
    try {
      if (this.wavFilePath) {
        fs.unlinkSync(this.wavFilePath)
      }
    } catch (e) {}
  }

  isRecordingActive(): boolean {
    return this.isRecording
  }
}
