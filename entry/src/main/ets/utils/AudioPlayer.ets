// entry/src/main/ets/utils/AudioPlayer.ets

import media from '@ohos.multimedia.media'
import fs from '@ohos.file.fs'

export interface AudioPlayStatus {
  isPlaying: boolean
  currentPosition: number
  duration: number
  progress: number
}

export class AudioPlayer {
  private avPlayer: media.AVPlayer | null = null
  private filePath: string = ''
  private isPlaying: boolean = false
  private isPaused: boolean = false
  private duration: number = 0
  private currentTime: number = 0

  private onProgressCallback: ((position: number, duration: number) => void) | null = null
  private onCompleteCallback: (() => void) | null = null
  private onErrorCallback: ((error: string) => void) | null = null

  async loadAudio(filePath: string): Promise<void> {
    try {
      this.filePath = filePath
      this.avPlayer = await media.createAVPlayer()

      if (!this.avPlayer) {
        throw new Error('创建 AVPlayer 失败')
      }

      const file = fs.openSync(filePath, fs.OpenMode.READ_ONLY)
      const fd = file.fd
      const stat = fs.statSync(filePath)

      // 设置数据源
      this.avPlayer.fdSrc = {
        fd: fd,
        offset: 0,
        length: stat.size
      }

      // 设置监听器
      this.setupListeners()

      // 准备播放
      await this.avPlayer.prepare()

      // 获取时长
      this.duration = this.avPlayer.duration || 0

      console.info('Audio loaded, duration:', this.duration)
    } catch (e) {
      console.error('Load audio failed:', e)
      throw new Error('加载音频失败')
    }
  }

  private setupListeners() {
    if (!this.avPlayer) return

    // 播放进度
    this.avPlayer.on('timeUpdate', (time: number) => {
      this.currentTime = time
      if (this.onProgressCallback) {
        this.onProgressCallback(time, this.duration)
      }
    })

    // 播放完成
    this.avPlayer.on('endOfStream', () => {
      this.isPlaying = false
      this.isPaused = false
      if (this.onCompleteCallback) {
        this.onCompleteCallback()
      }
    })

    // 错误
    this.avPlayer.on('error', (error: Error) => {
      console.error('AVPlayer error:', error)
      if (this.onErrorCallback) {
        this.onErrorCallback(`播放错误: ${error.message || '未知错误'}`)
      }
    })
  }

  async play(): Promise<void> {
    if (!this.avPlayer) {
      throw new Error('请先加载音频')
    }
    try {
      await this.avPlayer.play()
      this.isPlaying = true
      this.isPaused = false
    } catch (e) {
      console.error('Play failed:', e)
      throw new Error('播放失败')
    }
  }

  async pause(): Promise<void> {
    if (!this.avPlayer || !this.isPlaying) return
    try {
      await this.avPlayer.pause()
      this.isPlaying = false
      this.isPaused = true
    } catch (e) {
      console.error('Pause failed:', e)
    }
  }

  async resume(): Promise<void> {
    if (!this.avPlayer || !this.isPaused) return
    try {
      await this.avPlayer.play()
      this.isPlaying = true
      this.isPaused = false
    } catch (e) {
      console.error('Resume failed:', e)
    }
  }

  async stop(): Promise<void> {
    if (!this.avPlayer) return
    try {
      await this.avPlayer.stop()
      this.isPlaying = false
      this.isPaused = false
      this.currentTime = 0
    } catch (e) {
      console.error('Stop failed:', e)
    }
  }

  async seekTo(position: number): Promise<void> {
    if (!this.avPlayer) return
    try {
      await this.avPlayer.seek(position)
    } catch (e) {
      console.error('Seek failed:', e)
    }
  }

  async release(): Promise<void> {
    if (this.avPlayer) {
      try {
        await this.avPlayer.stop()
        await this.avPlayer.release()
      } catch (e) {
        console.error('Release error:', e)
      }
      this.avPlayer = null
      this.isPlaying = false
      this.isPaused = false
    }
  }

  getStatus(): AudioPlayStatus {
    return {
      isPlaying: this.isPlaying,
      currentPosition: this.currentTime,
      duration: this.duration,
      progress: this.duration > 0 ? this.currentTime / this.duration : 0
    }
  }

  isPlayingActive(): boolean {
    return this.isPlaying
  }

  isPausedActive(): boolean {
    return this.isPaused
  }

  onProgress(callback: (position: number, duration: number) => void): void {
    this.onProgressCallback = callback
  }

  onComplete(callback: () => void): void {
    this.onCompleteCallback = callback
  }

  onError(callback: (error: string) => void): void {
    this.onErrorCallback = callback
  }
}