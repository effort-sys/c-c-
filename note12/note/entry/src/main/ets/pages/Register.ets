import { DataManager } from '../utils/DataManager'
import router from '@ohos.router'
import promptAction from '@ohos.promptAction'

const PRIMARY_COLOR = '#007DFF'
const BG_COLOR_LIGHT = '#F5F5F5'
const TEXT_COLOR_WHITE = '#FFFFFF'

@Entry
@Component
struct Register {
  @State username: string = ''
  @State nickname: string = ''
  @State password: string = ''
  @State confirmPassword: string = ''
  @State showPassword: boolean = false
  @State showConfirmPassword: boolean = false
  private dataManager: DataManager | null = null

  aboutToAppear() {
    this.dataManager = DataManager.getInstance(getContext(this))
  }

  async handleRegister() {
    if (!this.username || !this.password || !this.confirmPassword) {
      promptAction.showToast({ message: '请填写完整信息' })
      return
    }
    if (this.password !== this.confirmPassword) {
      promptAction.showToast({ message: '两次输入的密码不一致' })
      return
    }
    if (this.username.length < 3) {
      promptAction.showToast({ message: '账号至少需要3个字符' })
      return
    }
    if (this.password.length < 6) {
      promptAction.showToast({ message: '密码至少需要6个字符' })
      return
    }
    if (this.dataManager) {
      const success = await this.dataManager.register(this.username, this.password, this.nickname)
      if (success) {
        promptAction.showToast({ message: '注册成功，请登录' })
        router.back()
      } else {
        promptAction.showToast({ message: '该账号已存在' })
      }
    }
  }

  build() {
    Column() {
      Image($r('app.media.biji'))
        .width(100)
        .height(100)
        .objectFit(ImageFit.Contain)
        .margin({ top: 60, bottom: 20 })
      Text('注册账号')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(PRIMARY_COLOR)
        .margin({ bottom: 40 })

      Column({ space: 20 }) {
        TextInput({ placeholder: '请输入账号', text: this.username })
          .width('80%')
          .height(50)
          .backgroundColor(BG_COLOR_LIGHT)
          .borderRadius(8)
          .padding({ left: 16 })
          .onChange((value: string) => {
            this.username = value
          })

        TextInput({ placeholder: '请输入昵称（可选）', text: this.nickname })
          .width('80%')
          .height(50)
          .backgroundColor(BG_COLOR_LIGHT)
          .borderRadius(8)
          .padding({ left: 16 })
          .onChange((value: string) => {
            this.nickname = value
          })

        Row() {
          TextInput({ placeholder: '请输入密码', text: this.password })
            .type(this.showPassword ? InputType.Normal : InputType.Password)
            .showPasswordIcon(false)
            .layoutWeight(1)
            .height(50)
            .backgroundColor(BG_COLOR_LIGHT)
            .borderRadius(8)
            .padding({ left: 16 })
            .onChange((value: string) => {
              this.password = value
            })

          Image(this.showPassword ? $r('app.media.eye_open') : $r('app.media.eye_close'))
            .width(24)
            .height(24)
            .margin({ left: -36 })
            .onClick(() => {
              this.showPassword = !this.showPassword
            })
        }
        .width('80%')
        .height(50)
        .padding({ right: 8 })

        Row() {
          TextInput({ placeholder: '请确认密码', text: this.confirmPassword })
            .type(this.showConfirmPassword ? InputType.Normal : InputType.Password)
            .showPasswordIcon(false)
            .layoutWeight(1)
            .height(50)
            .backgroundColor(BG_COLOR_LIGHT)
            .borderRadius(8)
            .padding({ left: 16 })
            .onChange((value: string) => {
              this.confirmPassword = value
            })

          Image(this.showConfirmPassword ? $r('app.media.eye_open') : $r('app.media.eye_close'))
            .width(24)
            .height(24)
            .margin({ left: -36 })
            .onClick(() => {
              this.showConfirmPassword = !this.showConfirmPassword
            })
        }
        .width('80%')
        .height(50)
        .padding({ right: 8 })

        Button('注册')
          .width('80%')
          .height(50)
          .backgroundColor(PRIMARY_COLOR)
          .borderRadius(8)
          .fontSize(18)
          .margin({ top: 20 })
          .onClick(() => {
            this.handleRegister()
          })

        Button('返回登录')
          .width('80%')
          .height(50)
          .backgroundColor(Color.Transparent)
          .fontColor(PRIMARY_COLOR)
          .borderRadius(8)
          .fontSize(16)
          .margin({ top: 10 })
          .onClick(() => {
            router.back()
          })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TEXT_COLOR_WHITE)
  }
}
