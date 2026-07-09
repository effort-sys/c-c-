import { DataManager } from '../utils/DataManager'
import router from '@ohos.router'
import promptAction from '@ohos.promptAction'

const PRIMARY_COLOR = '#007DFF'
const BG_COLOR_LIGHT = '#F5F5F5'
const TEXT_COLOR_PRIMARY = '#333333'
const TEXT_COLOR_SECONDARY = '#666666'
const TEXT_COLOR_WHITE = '#FFFFFF'

@Entry
@Component
struct Login {
  @State username: string = ''
  @State password: string = ''
  @State showPassword: boolean = false
  @State rememberLogin: boolean = false
  private dataManager: DataManager | null = null

  aboutToAppear() {
    this.dataManager = DataManager.getInstance(getContext(this))
    this.checkRememberLogin()
  }

  async checkRememberLogin() {
    if (this.dataManager) {
      const remember = await this.dataManager.getRememberLogin()
      if (remember) {
        const currentUser = await this.dataManager.getCurrentUser()
        if (currentUser) {
          router.replaceUrl({ url: 'pages/NoteList' })
        }
      }
    }
  }

  async handleLogin() {
    if (!this.username || !this.password) {
      promptAction.showToast({ message: '请输入账号和密码' })
      return
    }
    if (this.dataManager) {
      const success = await this.dataManager.login(this.username, this.password)
      if (success) {
        await this.dataManager.setRememberLogin(this.rememberLogin)
        promptAction.showToast({ message: '登录成功' })
        router.replaceUrl({ url: 'pages/NoteList' })
      } else {
        promptAction.showToast({ message: '账号或密码错误' })
      }
    }
  }

  goToRegister() {
    router.pushUrl({ url: 'pages/Register' })
  }

  build() {
    Column() {
      Image($r('app.media.biji'))
        .width(100)
        .height(100)
        .objectFit(ImageFit.Contain)
        .margin({ top: 60, bottom: 20 })
      Text('语音备忘录')
        .fontSize(36)
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
          Checkbox()
            .select(this.rememberLogin)
            .selectedColor(PRIMARY_COLOR)
            .onChange((value: boolean) => {
              this.rememberLogin = value
            })
          Text('记住登录')
            .fontSize(14)
            .fontColor(TEXT_COLOR_SECONDARY)
            .margin({ left: 4 })
        }
        .width('80%')
        .justifyContent(FlexAlign.Start)

        Button('登录')
          .width('80%')
          .height(50)
          .backgroundColor(PRIMARY_COLOR)
          .borderRadius(8)
          .fontSize(18)
          .margin({ top: 20 })
          .onClick(() => {
            this.handleLogin()
          })

        Button('注册账号')
          .width('80%')
          .height(50)
          .backgroundColor(Color.Transparent)
          .fontColor(PRIMARY_COLOR)
          .borderRadius(8)
          .fontSize(16)
          .margin({ top: 10 })
          .onClick(() => {
            this.goToRegister()
          })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TEXT_COLOR_WHITE)
  }
}
