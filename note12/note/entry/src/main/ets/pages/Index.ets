import router from '@ohos.router'

@Entry
@Component
struct Index {
  aboutToAppear() {
    setTimeout(() => {
      router.replaceUrl({ url: 'pages/Login' })
    }, 100)
  }

  build() {
    Column() {
      Text('语音备忘录')
        .fontSize(36)
        .fontWeight(FontWeight.Bold)
        .fontColor('#007DFF')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
    .justifyContent(FlexAlign.Center)
  }
}