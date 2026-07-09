// entry/src/main/ets/utils/SpeechToText.ets

import { speechRecognizer } from '@kit.CoreSpeechKit'
import fs from '@ohos.file.fs'

export interface SpeechResult {
  text: string
  confidence: number
  isFinal: boolean
}

export class SpeechToText {
  private isListening: boolean = false
  private resultCallback: ((result: SpeechResult) => void) | null = null
  private completeCallback: ((text: string) => void) | null = null
  private errorCallback: ((error: string) => void) | null = null

  private engine: speechRecognizer.SpeechRecognitionEngine | null = null
  private audioFilePath: string = ''
  private sessionId: string = ''
  private finalText: string = ''
  private writeTimerId: number = -1

  /**
   * 设置待识别的音频文件路径
   * @param filePath PCM 音频文件路径
   */
  setAudioFilePath(filePath: string): void {
    this.audioFilePath = filePath
  }

  async startRecognition(): Promise<void> {
    try {
      if (!this.audioFilePath) {
        throw new Error('请先设置音频文件路径')
      }

      this.isListening = true
      this.finalText = ''
      this.sessionId = `asr_${Date.now()}`

      // 创建识别引擎
      await this.createEngine()

      // 设置监听器
      this.setupListener()

      // 开始识别
      const startParams: speechRecognizer.StartParams = {
        sessionId: this.sessionId,
        audioInfo: {
          audioType: 'pcm',
          sampleRate: 16000,
          soundChannel: 1,
          sampleBit: 16
        },
        extraParams: {
          'recognitionMode': 1, // 1: 实时音频转文字识别（通过writeAudio写入）
          'vadEnd': 1000,
          'maxAudioDuration': 300000, // 最大支持 5 分钟
          'recognizerOption': {
            'enablePartialResult': true
          }
        }
      }

      this.engine?.startListening(startParams)

      // 从文件读取音频并写入
      this.streamAudioFromFile()

      console.info('Speech recognition started')
    } catch (e) {
      console.error('Start recognition failed:', e)
      this.isListening = false
      throw new Error('启动语音识别失败')
    }
  }

  private async createEngine(): Promise<void> {
    return new Promise((resolve, reject) => {
      const createParams: speechRecognizer.CreateEngineParams = {
        language: 'zh-CN',
        online: 0 // 0: 离线模式
      }

      speechRecognizer.createEngine(createParams, (err, engine) => {
        if (err) {
          console.error('Create engine failed:', err)
          reject(new Error('创建识别引擎失败'))
          return
        }
        this.engine = engine
        resolve()
      })
    })
  }

  private setupListener(): void {
    if (!this.engine) return

    const listener: speechRecognizer.RecognitionListener = {
      onStart: (sessionId: string, eventMessage: string) => {
        console.info(`onStart, sessionId: ${sessionId}, message: ${eventMessage}`)
      },

      onEvent: (sessionId: string, eventCode: number, eventMessage: string) => {
        console.info(`onEvent, sessionId: ${sessionId}, code: ${eventCode}, message: ${eventMessage}`)
      },

      onResult: (sessionId: string, result: speechRecognizer.SpeechRecognitionResult) => {
        console.info(`onResult, sessionId: ${sessionId}, result: ${JSON.stringify(result)}`)

        const text = result.result || ''
        const isFinal = result.isFinal || false

        if (this.resultCallback) {
          this.resultCallback({
            text: text,
            confidence: 0.9,
            isFinal: isFinal
          })
        }

        if (isFinal && text) {
          this.finalText += text
        } else if (!isFinal && text) {
          // 中间结果也更新显示
          if (this.resultCallback) {
            this.resultCallback({
              text: this.finalText + text,
              confidence: 0.8,
              isFinal: false
            })
          }
        }
      },

      onComplete: (sessionId: string, eventMessage: string) => {
        console.info(`onComplete, sessionId: ${sessionId}, message: ${eventMessage}`)
        this.isListening = false
        this.stopWriteTimer()

        if (this.completeCallback) {
          this.completeCallback(this.finalText)
        }
      },

      onError: (sessionId: string, errorCode: number, errorMessage: string) => {
        console.error(`onError, sessionId: ${sessionId}, code: ${errorCode}, message: ${errorMessage}`)
        this.isListening = false
        this.stopWriteTimer()

        if (this.errorCallback) {
          this.errorCallback(`识别错误: ${errorMessage}`)
        }
      }
    }

    this.engine.setListener(listener)
  }

  private streamAudioFromFile(): void {
    try {
      const file = fs.openSync(this.audioFilePath, fs.OpenMode.READ_ONLY)
      const stat = fs.statSync(this.audioFilePath)
      const fileSize = stat.size

      // 读取文件头，检测是否是 WAV 格式
      const headerBuffer = new ArrayBuffer(12)
      const headerBytesRead = fs.readSync(file.fd, headerBuffer)
      
      let dataOffset = 0
      if (headerBytesRead >= 12) {
        const headerView = new Uint8Array(headerBuffer)
        // 检查是否是 "RIFF" + "WAVE"
        if (headerView[0] === 0x52 && headerView[1] === 0x49 && 
            headerView[2] === 0x46 && headerView[3] === 0x46 &&
            headerView[8] === 0x57 && headerView[9] === 0x41 &&
            headerView[10] === 0x56 && headerView[11] === 0x45) {
          // 是 WAV 文件，跳过 44 字节文件头
          dataOffset = 44
        }
      }

      // 移动到音频数据开始位置
      if (dataOffset > 0) {
        fs.closeSync(file.fd)
        const file2 = fs.openSync(this.audioFilePath, fs.OpenMode.READ_ONLY)
        const skipBuffer = new ArrayBuffer(dataOffset)
        fs.readSync(file2.fd, skipBuffer)
        
        const dataSize = fileSize - dataOffset
        const fullData = new Uint8Array(dataSize)
        
        const readChunkSize = 8192
        let offset = 0
        while (offset < dataSize) {
          const chunkSize = Math.min(readChunkSize, dataSize - offset)
          const chunkBuffer = new ArrayBuffer(chunkSize)
          const bytesRead = fs.readSync(file2.fd, chunkBuffer)
          if (bytesRead <= 0) break
          fullData.set(new Uint8Array(chunkBuffer.slice(0, bytesRead)), offset)
          offset += bytesRead
        }
        
        fs.closeSync(file2.fd)
        this.startStreaming(fullData)
      } else {
        // 是 PCM 文件，直接读取全部数据
        fs.closeSync(file.fd)
        const file2 = fs.openSync(this.audioFilePath, fs.OpenMode.READ_ONLY)
        const fullData = new Uint8Array(fileSize)
        
        const readChunkSize = 8192
        let offset = 0
        while (offset < fileSize) {
          const chunkSize = Math.min(readChunkSize, fileSize - offset)
          const chunkBuffer = new ArrayBuffer(chunkSize)
          const bytesRead = fs.readSync(file2.fd, chunkBuffer)
          if (bytesRead <= 0) break
          fullData.set(new Uint8Array(chunkBuffer.slice(0, bytesRead)), offset)
          offset += bytesRead
        }
        
        fs.closeSync(file2.fd)
        this.startStreaming(fullData)
      }
    } catch (e) {
      console.error('Stream audio from file failed:', e)
      if (this.errorCallback) {
        this.errorCallback('读取音频文件失败')
      }
      this.isListening = false
    }
  }

  private startStreaming(fullData: Uint8Array): void {
    // 按 640 字节分块，每 20ms 写一块
    const chunkSize = 640 // 20ms 的 16kHz 16bit 单声道 PCM 数据大小
    let currentOffset = 0
    
    this.writeTimerId = setInterval(() => {
      if (!this.isListening || !this.engine) {
        this.stopWriteTimer()
        return
      }

      if (currentOffset >= fullData.length) {
        // 文件读完，调用 finish
        this.stopWriteTimer()
        try {
          this.engine?.finish(this.sessionId)
        } catch (e) {
          console.error('Finish recognition failed:', e)
        }
        return
      }

      try {
        const end = Math.min(currentOffset + chunkSize, fullData.length)
        const chunk = fullData.slice(currentOffset, end)
        this.engine?.writeAudio(this.sessionId, chunk)
        currentOffset = end
      } catch (e) {
        console.error('Write audio chunk failed:', e)
        this.stopWriteTimer()
        if (this.errorCallback) {
          this.errorCallback('写入音频数据失败')
        }
        this.isListening = false
      }
    }, 20) // 每 20ms 写一块
  }

  private stopWriteTimer(): void {
    if (this.writeTimerId !== -1) {
      clearInterval(this.writeTimerId)
      this.writeTimerId = -1
    }
  }

  async stopRecognition(): Promise<void> {
    this.isListening = false
    this.stopWriteTimer()

    if (this.engine && this.sessionId) {
      try {
        this.engine.finish(this.sessionId)
      } catch (e) {
        console.error('Stop recognition failed:', e)
      }
    }

    console.info('Recognition stopped')
  }

  async cancelRecognition(): Promise<void> {
    this.isListening = false
    this.stopWriteTimer()

    if (this.engine && this.sessionId) {
      try {
        this.engine.cancel(this.sessionId)
      } catch (e) {
        console.error('Cancel recognition failed:', e)
      }
    }

    console.info('Recognition cancelled')
  }

  async release(): Promise<void> {
    this.isListening = false
    this.stopWriteTimer()

    if (this.engine) {
      try {
        this.engine.shutdown()
      } catch (e) {
        console.error('Shutdown engine failed:', e)
      }
      this.engine = null
    }

    this.resultCallback = null
    this.completeCallback = null
    this.errorCallback = null
    this.audioFilePath = ''
    this.sessionId = ''
    this.finalText = ''
  }

  onResult(callback: (result: SpeechResult) => void): void {
    this.resultCallback = callback
  }

  onComplete(callback: (text: string) => void): void {
    this.completeCallback = callback
  }

  onError(callback: (error: string) => void): void {
    this.errorCallback = callback
  }

  isListeningActive(): boolean {
    return this.isListening
  }
}
