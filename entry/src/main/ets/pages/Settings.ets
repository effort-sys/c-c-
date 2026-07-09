import { DataManager } from '../utils/DataManager'
import router from '@ohos.router'
import promptAction from '@ohos.promptAction'

const PRIMARY_COLOR = '#007DFF'
const BG_COLOR_LIGHT = '#F5F5F5'
const TEXT_COLOR_PRIMARY = '#333333'
const TEXT_COLOR_SECONDARY = '#666666'
const TEXT_COLOR_WHITE = '#FFFFFF'
const TEXT_COLOR_DANGER = '#FF4D4F'

@Entry
@Component
struct Settings {
  @State currentUser: string = ''
  @State nickname: string = ''
  @State editingNickname: boolean = false
  @State newNickname: string = ''
  @State isLoading: boolean = true
  private dataManager: DataManager | null = null

  aboutToAppear() {
    this.dataManager = DataManager.getInstance(getContext(this))
    this.loadData()
  }

  async loadData() {
    if (this.dataManager) {
      this.currentUser = await this.dataManager.getCurrentUser()
      this.nickname = await this.dataManager.getUserNickname(this.currentUser)
      this.newNickname = this.nickname
    }
    this.isLoading = false
  }

  startEditNickname() {
    this.newNickname = this.nickname
    this.editingNickname = true
  }

  async saveNickname() {
    if (!this.newNickname.trim()) {
      promptAction.showToast({ message: '昵称不能为空' })
      return
    }

    if (this.dataManager) {
      const success = await this.dataManager.updateUserNickname(this.currentUser, this.newNickname.trim())
      if (success) {
        this.nickname = this.newNickname.trim()
        this.editingNickname = false
        promptAction.showToast({ message: '昵称修改成功' })
      }
    }
  }

  async logout() {
    promptAction.showDialog({
      title: '提示',
      message: '确定要退出登录吗？',
      buttons: [
        { text: '取消', color: '#666666' },
        { text: '退出', color: '#007DFF' }
      ]
    }).then(async (result) => {
      if (result.index === 1 && this.dataManager) {
        await this.dataManager.logout()
        router.replaceUrl({ url: 'pages/Login' })
      }
    })
  }

  build() {
    Column() {
      this.buildHeader()

      if (!this.isLoading) {
        this.buildContent()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(BG_COLOR_LIGHT)
  }

  @Builder
  buildHeader() {
    Row() {
      Button() {
        Image($r('app.media.tui'))
          .width(22)
          .height(22)
          .objectFit(ImageFit.Contain)
      }
      .width(40)
      .height(40)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        router.back()
      })

      Text('设置')
        .layoutWeight(1)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.Center)

      Column()
        .width(40)
    }
    .width('100%')
    .height(48)
    .padding({ left: 10, right: 10 })
    .backgroundColor(TEXT_COLOR_WHITE)
  }

  @Builder
  buildContent() {
    Column({ space: 12 }) {
      this.buildUserInfo()
      this.buildMenuItems()
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 20 })
  }

  @Builder
  buildUserInfo() {
    Column() {
      Row() {
        Column() {
          Text(this.nickname.substring(0, 1).toUpperCase())
            .fontSize(24)
            .fontColor(TEXT_COLOR_WHITE)
            .fontWeight(FontWeight.Bold)
        }
        .width(56)
        .height(56)
        .borderRadius(28)
        .backgroundColor(PRIMARY_COLOR)
        .justifyContent(FlexAlign.Center)

        Column({ space: 4 }) {
          Text(this.nickname)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(TEXT_COLOR_PRIMARY)

          Text('账号: ' + this.currentUser)
            .fontSize(12)
            .fontColor(TEXT_COLOR_SECONDARY)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 12 })
      }
      .width('100%')
      .padding(14)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .backgroundColor(TEXT_COLOR_WHITE)
    .borderRadius(10)
  }

  @Builder
  buildMenuItems() {
    Column({ space: 0 }) {
      if (this.editingNickname) {
        Row() {
          Text('修改昵称')
            .fontSize(15)
            .fontColor(TEXT_COLOR_PRIMARY)
          
          Blank()

          TextInput({ placeholder: '请输入新昵称', text: this.newNickname })
            .width(150)
            .height(36)
            .backgroundColor(BG_COLOR_LIGHT)
            .borderRadius(6)
            .padding({ left: 10, right: 10 })
            .fontSize(14)
            .onChange((value: string) => {
              this.newNickname = value
            })

          Button('取消')
            .height(32)
            .margin({ left: 8 })
            .backgroundColor(Color.Transparent)
            .fontColor(TEXT_COLOR_SECONDARY)
            .fontSize(14)
            .onClick(() => {
              this.editingNickname = false
            })

          Button('保存')
            .height(32)
            .margin({ left: 4 })
            .backgroundColor(PRIMARY_COLOR)
            .fontColor(TEXT_COLOR_WHITE)
            .fontSize(14)
            .onClick(() => {
              this.saveNickname()
            })
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 14, bottom: 14 })
        .alignItems(VerticalAlign.Center)
        .backgroundColor(TEXT_COLOR_WHITE)
      } else {
        this.buildMenuItem('修改昵称', '', () => {
          this.startEditNickname()
        })
      }

      this.buildDivider()

      this.buildMenuItem('关于我们', '尉来笔记 v1.0.0', () => {
        promptAction.showToast({ message: '尉来笔记 - 记录美好生活' })
      })

      this.buildDivider()

      this.buildMenuItem('帮助反馈', '', () => {
        promptAction.showToast({ message: '感谢您的反馈！' })
      })
    }
    .width('100%')
    .backgroundColor(TEXT_COLOR_WHITE)
    .borderRadius(10)

    Button('退出登录')
      .width('100%')
      .height(48)
      .margin({ top: 24 })
      .backgroundColor('#FFF0F0')
      .fontColor(TEXT_COLOR_DANGER)
      .fontSize(16)
      .borderRadius(10)
      .onClick(() => {
        this.logout()
      })
  }

  @Builder
  buildMenuItem(title: string, desc: string, callback: () => void) {
    Row() {
      Text(title)
        .fontSize(15)
        .fontColor(TEXT_COLOR_PRIMARY)

      Blank()

      if (desc) {
        Text(desc)
          .fontSize(13)
          .fontColor(TEXT_COLOR_SECONDARY)
      }

      Column() {
        Image($r('app.media.tui'))
          .width(16)
          .height(16)
      }
      .margin({ left: 6 })
      .transform({
        rotate: {
          angle: 180
        }
      })
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
    .onClick(() => {
      callback()
    })
  }

  @Builder
  buildDivider() {
    Column()
      .width('100%')
      .height(0.5)
      .backgroundColor('#E8E8E8')
      .margin({ left: 14 })
  }
}
