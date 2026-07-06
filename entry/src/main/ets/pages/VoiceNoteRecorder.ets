// entry/src/main/ets/pages/VoiceNoteRecorder.ets

import { AudioRecorder, AudioRecordResult } from '../utils/AudioRecorder'
import { AudioPlayer } from '../utils/AudioPlayer'
import { SpeechToText, SpeechResult } from '../utils/SpeechToText'
import { DataManager } from '../utils/DataManager'
import router from '@ohos.router'
import promptAction from '@ohos.promptAction'

const PRIMARY_COLOR = '#007DFF'
const BG_COLOR_LIGHT = '#F5F5F5'
const TEXT_COLOR_WHITE = '#FFFFFF'
const TEXT_COLOR_PRIMARY = '#333333'
const TEXT_COLOR_TERTIARY = '#999999'
const TEXT_COLOR_DANGER = '#FF4D4F'

@Entry
@Component
struct VoiceNoteRecorder {
  @State isRecording: boolean = false
  @State isPlaying: boolean = false
  @State recordDuration: number = 0
  @State playProgress: number = 0
  @State playPosition: number = 0
  @State totalDuration: number = 0
  @State recognizedText: string = ''
  @State isRecognizing: boolean = false
  @State recordFilePath: string = ''
  @State showPlayback: boolean = false
  @State title: string = ''

  private audioRecorder: AudioRecorder | null = null
  private audioPlayer: AudioPlayer = new AudioPlayer()
  private speechToText: SpeechToText = new SpeechToText()
  private dataManager: DataManager | null = null
  private timerId: number = -1
  private currentUser: string = ''

  aboutToAppear() {
    const context = getContext(this)
    this.dataManager = DataManager.getInstance(context)
    this.audioRecorder = new AudioRecorder(context)
    this.initData()
    this.setupAudioPlayerCallbacks()
    this.setupSpeechCallbacks()
  }

  aboutToDisappear() {
    this.stopTimer()
    this.cleanup()
  }

  async initData() {
    if (this.dataManager) {
      this.currentUser = await this.dataManager.getCurrentUser()
    }
  }

  private setupAudioPlayerCallbacks() {
    this.audioPlayer.onProgress((position: number, duration: number) => {
      this.playPosition = position
      this.totalDuration = duration
      this.playProgress = duration > 0 ? position / duration : 0
    })

    this.audioPlayer.onComplete(() => {
      this.isPlaying = false
      this.playProgress = 1
      promptAction.showToast({ message: '播放完成' })
    })

    this.audioPlayer.onError((error: string) => {
      promptAction.showToast({ message: error })
      this.isPlaying = false
    })
  }

  private setupSpeechCallbacks() {
    this.speechToText.onResult((result: SpeechResult) => {
      this.recognizedText = result.text
    })

    this.speechToText.onComplete((text: string) => {
      this.isRecognizing = false
      this.recognizedText = text
      if (text) {
        promptAction.showToast({ message: '语音转文字完成' })
        if (!this.title) {
          this.title = text.length > 20 ? text.substring(0, 20) + '...' : text
        }
      }
    })

    this.speechToText.onError((error: string) => {
      this.isRecognizing = false
      promptAction.showToast({ message: error })
    })
  }

  async startRecording() {
    try {
      if (!this.audioRecorder) return

      const filePath = await this.audioRecorder.startRecording()
      this.recordFilePath = filePath
      this.isRecording = true
      this.showPlayback = false
      this.recordDuration = 0
      this.recognizedText = ''
      this.title = ''

      this.startTimer()
      promptAction.showToast({ message: '开始录音' })
    } catch (e) {
      promptAction.showToast({ message: '录音启动失败，请检查麦克风权限' })
      console.error('startRecording error:', e)
    }
  }

  async stopRecording() {
    if (!this.isRecording || !this.audioRecorder) return

    try {
      this.stopTimer()
      const result = await this.audioRecorder.stopRecording()
      this.isRecording = false
      this.recordDuration = result.duration
      this.showPlayback = true

      // 自动进行语音转文字
      await this.startSpeechToText()

      promptAction.showToast({ message: '录音完成' })
    } catch (e) {
      promptAction.showToast({ message: '停止录音失败' })
      console.error('stopRecording error:', e)
    }
  }

  async cancelRecording() {
    if (!this.isRecording || !this.audioRecorder) return

    try {
      this.stopTimer()
      await this.audioRecorder.cancelRecording()
      this.isRecording = false
      this.showPlayback = false
      promptAction.showToast({ message: '已取消录音' })
    } catch (e) {
      console.error('cancelRecording error:', e)
    }
  }

  async startSpeechToText() {
    try {
      if (!this.recordFilePath) {
        promptAction.showToast({ message: '没有录音文件可识别' })
        return
      }

      this.isRecognizing = true
      this.recognizedText = ''
      this.speechToText.setAudioFilePath(this.recordFilePath)
      await this.speechToText.startRecognition()
    } catch (e) {
      console.error('startSpeechToText error:', e)
      this.isRecognizing = false
      promptAction.showToast({ message: '语音识别启动失败' })
    }
  }

  async playRecording() {
    if (!this.recordFilePath) {
      promptAction.showToast({ message: '没有可播放的录音' })
      return
    }

    try {
      if (this.isPlaying) {
        await this.audioPlayer.pause()
        this.isPlaying = false
        return
      }

      if (this.audioPlayer.isPausedActive()) {
        await this.audioPlayer.resume()
        this.isPlaying = true
        return
      }

      await this.audioPlayer.loadAudio(this.recordFilePath)
      await this.audioPlayer.play()
      this.isPlaying = true
    } catch (e) {
      promptAction.showToast({ message: '播放失败' })
      console.error('playRecording error:', e)
    }
  }

  async stopPlayback() {
    try {
      await this.audioPlayer.stop()
      this.isPlaying = false
      this.playProgress = 0
      this.playPosition = 0
    } catch (e) {
      console.error('stopPlayback error:', e)
    }
  }

  async onProgressChange(value: number) {
    if (this.totalDuration > 0) {
      const position = value * this.totalDuration
      await this.audioPlayer.seekTo(position)
      this.playProgress = value
    }
  }

  async saveVoiceNote() {
    if (!this.recordFilePath) {
      promptAction.showToast({ message: '没有录音内容' })
      return
    }

    if (!this.title.trim() && !this.recognizedText.trim()) {
      promptAction.showToast({ message: '请输入标题或内容' })
      return
    }

    try {
      const content = this.recognizedText || '语音笔记'
      const title = this.title.trim() || content.substring(0, 20)

      await this.dataManager?.addNote(
        this.currentUser,
        title,
        content,
        '语音',
        '🎙️',
        '#FFF9C4'
      )

      promptAction.showToast({ message: '语音笔记保存成功' })

      await this.cleanup()
      router.back()
    } catch (e) {
      promptAction.showToast({ message: '保存失败' })
      console.error('saveVoiceNote error:', e)
    }
  }

  private startTimer() {
    this.timerId = setInterval(() => {
      this.recordDuration += 1000
    }, 1000)
  }

  private stopTimer() {
    if (this.timerId !== -1) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
  }

  async cleanup() {
    this.stopTimer()
    if (this.audioRecorder) {
      await this.audioRecorder.cancelRecording()
    }
    await this.audioPlayer.release()
    await this.speechToText.release()
    this.isRecording = false
    this.isPlaying = false
  }

  formatTime(ms: number): string {
    const totalSeconds = Math.floor(ms / 1000)
    const minutes = Math.floor(totalSeconds / 60)
    const seconds = totalSeconds % 60
    return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Button('←')
          .width(40)
          .height(40)
          .fontSize(20)
          .backgroundColor(Color.Transparent)
          .fontColor(TEXT_COLOR_PRIMARY)
          .onClick(() => {
            if (this.isRecording) {
              promptAction.showDialog({
                title: '提示',
                message: '录音正在进行，确定要退出吗？',
                buttons: [
                  { text: '取消', color: '#666666' },
                  { text: '退出', color: '#007DFF' }
                ]
              }).then((result) => {
                if (result.index === 1) {
                  this.cancelRecording()
                  router.back()
                }
              })
            } else {
              router.back()
            }
          })

        Text('语音备忘录')
          .layoutWeight(1)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .textAlign(TextAlign.Center)

        if (!this.isRecording && !this.showPlayback) {
          Button('+')
            .width(40)
            .height(40)
            .fontSize(24)
            .backgroundColor(Color.Transparent)
            .fontColor(PRIMARY_COLOR)
            .onClick(() => {
              this.startRecording()
            })
        } else {
          Blank()
        }
      }
      .width('100%')
      .height(48)
      .padding({ left: 10, right: 10 })
      .backgroundColor(TEXT_COLOR_WHITE)

      // 主内容区域
      Column({ space: 20 }) {
        if (this.isRecording) {
          // 录音中
          Column({ space: 20 }) {
            Column() {
              Text('🎙️')
                .fontSize(64)
            }
            .width(120)
            .height(120)
            .borderRadius(60)
            .backgroundColor(TEXT_COLOR_DANGER + '20')
            .justifyContent(FlexAlign.Center)

            Text(this.formatTime(this.recordDuration))
              .fontSize(48)
              .fontWeight(FontWeight.Bold)
              .fontColor(TEXT_COLOR_PRIMARY)

            Text('录音中...')
              .fontSize(16)
              .fontColor(TEXT_COLOR_TERTIARY)

            // 声波动画
            Row({ space: 4 }) {
              ForEach([1, 2, 3, 4, 5, 6, 7, 8], (index: number) => {
                Column()
                  .width(4)
                  .height(20 + Math.random() * 40)
                  .backgroundColor(PRIMARY_COLOR)
                  .borderRadius(2)
              })
            }
            .height(60)
            .justifyContent(FlexAlign.Center)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)

        } else if (this.showPlayback) {
          // 播放预览
          Column({ space: 20 }) {
            Text('🎙️ 录音预览')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)

            Column({ space: 8 }) {
              Slider({
                value: this.playProgress,
                min: 0,
                max: 1,
                step: 0.01
              })
                .width('100%')
                .onChange((value: number) => {
                  this.onProgressChange(value)
                })

              Row() {
                Text(this.formatTime(this.playPosition))
                  .fontSize(12)
                  .fontColor(TEXT_COLOR_TERTIARY)
                Blank()
                Text(this.formatTime(this.totalDuration))
                  .fontSize(12)
                  .fontColor(TEXT_COLOR_TERTIARY)
              }
              .width('100%')
            }

            Row({ space: 40 }) {
              Button('⏹')
                .width(56)
                .height(56)
                .fontSize(24)
                .borderRadius(28)
                .backgroundColor(BG_COLOR_LIGHT)
                .onClick(() => {
                  this.stopPlayback()
                })

              Button(this.isPlaying ? '⏸' : '▶️')
                .width(64)
                .height(64)
                .fontSize(28)
                .borderRadius(32)
                .backgroundColor(PRIMARY_COLOR)
                .fontColor(TEXT_COLOR_WHITE)
                .onClick(() => {
                  this.playRecording()
                })
            }

            if (this.isRecognizing) {
              Text('🔄 正在转文字...')
                .fontSize(14)
                .fontColor(TEXT_COLOR_TERTIARY)
            }

            if (this.recognizedText) {
              Column({ space: 8 }) {
                Row() {
                  Text('📝 识别结果')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                }
                .width('100%')

                Text(this.recognizedText)
                  .width('100%')
                  .fontSize(14)
                  .fontColor(TEXT_COLOR_PRIMARY)
                  .padding(12)
                  .backgroundColor('#F0F8FF')
                  .borderRadius(8)
              }
              .width('100%')
            }

            TextInput({ placeholder: '请输入笔记标题（可选）', text: this.title })
              .width('100%')
              .height(44)
              .backgroundColor(BG_COLOR_LIGHT)
              .borderRadius(8)
              .padding({ left: 12, right: 12 })
              .onChange((value: string) => {
                this.title = value
              })
          }
          .width('100%')

        } else {
          // 空闲状态
          Column({ space: 20 }) {
            Text('🎙️')
              .fontSize(80)

            Text('点击下方按钮开始录音')
              .fontSize(16)
              .fontColor(TEXT_COLOR_TERTIARY)

            Text('支持语音转文字，快速生成笔记')
              .fontSize(13)
              .fontColor(TEXT_COLOR_TERTIARY)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
      }
      .layoutWeight(1)
      .width('100%')
      .padding(20)
      .justifyContent(FlexAlign.Center)

      // 底部按钮
      Row() {
        if (this.isRecording) {
          Button('取消')
            .width('45%')
            .height(48)
            .backgroundColor(BG_COLOR_LIGHT)
            .fontColor(TEXT_COLOR_PRIMARY)
            .borderRadius(8)
            .fontSize(16)
            .onClick(() => {
              this.cancelRecording()
            })

          Button('停止')
            .width('45%')
            .height(48)
            .backgroundColor(TEXT_COLOR_DANGER)
            .fontColor(TEXT_COLOR_WHITE)
            .borderRadius(8)
            .fontSize(16)
            .onClick(() => {
              this.stopRecording()
            })
        } else if (this.showPlayback) {
          Button('重新录制')
            .width('45%')
            .height(48)
            .backgroundColor(BG_COLOR_LIGHT)
            .fontColor(TEXT_COLOR_PRIMARY)
            .borderRadius(8)
            .fontSize(16)
            .onClick(() => {
              this.showPlayback = false
              this.recordFilePath = ''
              this.recognizedText = ''
              this.title = ''
              this.playProgress = 0
              this.audioPlayer.release()
            })

          Button('保存笔记')
            .width('45%')
            .height(48)
            .backgroundColor(PRIMARY_COLOR)
            .fontColor(TEXT_COLOR_WHITE)
            .borderRadius(8)
            .fontSize(16)
            .onClick(() => {
              this.saveVoiceNote()
            })
        } else {
          Button('开始录音')
            .width('80%')
            .height(56)
            .backgroundColor(PRIMARY_COLOR)
            .fontColor(TEXT_COLOR_WHITE)
            .borderRadius(28)
            .fontSize(18)
            .onClick(() => {
              this.startRecording()
            })
        }
      }
      .width('100%')
      .padding(20)
      .backgroundColor(TEXT_COLOR_WHITE)
      .justifyContent(FlexAlign.SpaceEvenly)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}
