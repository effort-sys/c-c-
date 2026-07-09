import { DataManager, Note, Category, CATEGORIES, MOODS, BG_COLORS } from '../utils/DataManager'
import router from '@ohos.router'
import promptAction from '@ohos.promptAction'

const PRIMARY_COLOR = '#007DFF'
const BG_COLOR_LIGHT = '#F5F5F5'
const TEXT_COLOR_PRIMARY = '#333333'
const TEXT_COLOR_TERTIARY = '#999999'
const TEXT_COLOR_WHITE = '#FFFFFF'

@Entry
@Component
struct NoteEdit {
  @State title: string = ''
  @State content: string = ''
  @State originalTitle: string = ''
  @State originalContent: string = ''
  @State isEditMode: boolean = false
  @State noteId: string = ''
  @State currentUser: string = ''
  @State selectedCategory: string = ''
  @State selectedMood: string = ''
  @State selectedBgColor: string = '#FFFFFF'
  @State showSheet: boolean = false
  @State sheetType: 'category' | 'mood' | null = null
  @State isSaving: boolean = false
  @State isLoading: boolean = true
  private dataManager: DataManager | null = null
  private originalNote: Note | null = null

  get hasChanges(): boolean {
    return this.title !== this.originalTitle || this.content !== this.originalContent ||
      this.selectedCategory !== (this.originalNote?.category || '') ||
      this.selectedMood !== (this.originalNote?.mood || '') ||
      this.selectedBgColor !== (this.originalNote?.bgColor || '#FFFFFF')
  }

  aboutToAppear() {
    this.dataManager = DataManager.getInstance(getContext(this))
    this.initData()
  }

  async initData() {
    try {
      const params = router.getParams() as Record<string, Object>
      if (params) {
        this.noteId = params['noteId'] as string
        this.originalTitle = params['title'] as string || ''
        this.originalContent = params['content'] as string || ''
        this.title = this.originalTitle
        this.content = this.originalContent
        this.isEditMode = !!this.noteId

        if (params['note']) {
          this.originalNote = params['note'] as Note
          this.selectedCategory = this.originalNote.category || ''
          this.selectedMood = this.originalNote.mood || ''
          this.selectedBgColor = this.originalNote.bgColor || '#FFFFFF'
        }
      }

      if (this.dataManager) {
        this.currentUser = await this.dataManager.getCurrentUser()
      }
    } catch (e) {
      console.error('initData error:', e)
    } finally {
      this.isLoading = false
    }
  }

  async saveNote() {
    if (!this.dataManager) return
    if (this.title.trim() === '' && this.content.trim() === '') {
      promptAction.showToast({ message: '请输入笔记内容' })
      return
    }

    this.isSaving = true

    try {
      if (this.isEditMode) {
        await this.dataManager.updateNote(this.noteId, this.title, this.content, this.selectedCategory, this.selectedMood, this.selectedBgColor)
        promptAction.showToast({ message: '保存成功' })
      } else {
        await this.dataManager.addNote(this.currentUser, this.title, this.content, this.selectedCategory, this.selectedMood, this.selectedBgColor)
        promptAction.showToast({ message: '保存成功' })
      }
      router.back()
    } catch (e) {
      promptAction.showToast({ message: '保存失败，请重试' })
    } finally {
      this.isSaving = false
    }
  }

  goBack() {
    if (this.hasChanges) {
      promptAction.showDialog({
        title: '提示',
        message: '你有未保存的内容，确定要离开吗？',
        buttons: [
          { text: '取消', color: '#666666' },
          { text: '离开', color: '#007DFF' }
        ]
      }).then((result) => {
        if (result.index === 1) {
          router.back()
        }
      })
    } else {
      router.back()
    }
  }

  build() {
    Column() {
      // 标题栏
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
          this.goBack()
        })

        Text(this.isEditMode ? '编辑笔记' : '新建笔记')
          .layoutWeight(1)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .textAlign(TextAlign.Center)

        Button('保存')
          .width(60)
          .height(32)
          .backgroundColor(PRIMARY_COLOR)
          .borderRadius(16)
          .fontSize(13)
          .enabled(!this.isSaving)
          .onClick(() => {
            this.saveNote()
          })
      }
      .width('100%')
      .height(48)
      .padding({ left: 10, right: 10 })
      .backgroundColor(TEXT_COLOR_WHITE)

      // 内容区域
      Column({ space: 9 }) {
        // 标题输入
        TextInput({ placeholder: '请输入标题', text: this.title })
          .width('100%')
          .height(44)
          .backgroundColor(BG_COLOR_LIGHT)
          .borderRadius(6)
          .padding({ left: 12, right: 12 })
          .fontSize(16)
          .onChange((value: string) => {
            this.title = value
          })

        // 内容输入
        TextArea({ placeholder: '请输入笔记内容', text: this.content })
          .width('100%')
          .height(160)
          .backgroundColor(BG_COLOR_LIGHT)
          .borderRadius(6)
          .padding(12)
          .fontSize(14)
          .onChange((value: string) => {
            this.content = value
          })

        // 字数统计
        Text(`字数: ${this.title.length + this.content.length}`)
          .width('100%')
          .fontSize(11)
          .fontColor(TEXT_COLOR_TERTIARY)

        // 分类选择
        Row() {
          Text('分类')
            .fontSize(13)
            .fontColor(TEXT_COLOR_PRIMARY)
          Blank()
          Button(this.selectedCategory || '选择分类')
            .height(28)
            .borderRadius(14)
            .fontSize(12)
            .backgroundColor(BG_COLOR_LIGHT)
            .fontColor(TEXT_COLOR_PRIMARY)
            .onClick(() => {
              this.sheetType = 'category'
              this.showSheet = true
            })
        }
        .width('100%')

        // 心情选择
        Row() {
          Text('心情')
            .fontSize(13)
            .fontColor(TEXT_COLOR_PRIMARY)
          Blank()
          Button(this.selectedMood || '选择心情')
            .height(28)
            .borderRadius(14)
            .fontSize(12)
            .backgroundColor(BG_COLOR_LIGHT)
            .fontColor(TEXT_COLOR_PRIMARY)
            .onClick(() => {
              this.sheetType = 'mood'
              this.showSheet = true
            })
        }
        .width('100%')

        // 背景色选择
        Row() {
          Text('背景色')
            .fontSize(13)
            .fontColor(TEXT_COLOR_PRIMARY)
          Blank()
          Row({ space: 6 }) {
            ForEach(BG_COLORS, (color: string) => {
              Column()
                .width(20)
                .height(20)
                .backgroundColor(color)
                .borderRadius(10)
                .border({
                  width: this.selectedBgColor === color ? 2 : 0,
                  color: PRIMARY_COLOR
                })
                .onClick(() => {
                  this.selectedBgColor = color
                })
            })
          }
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .justifyContent(FlexAlign.Start)
      .layoutWeight(1)
      .backgroundColor(this.selectedBgColor)
    }
    .width('100%')
    .height('100%')
    .bindSheet(this.showSheet, this.buildSheet(), {
      height: 320,
      dragBar: true,
      onDisappear: () => {
        this.showSheet = false
        this.sheetType = null
      }
    })
  }

  @Builder
  buildSheet() {
    Column() {
      if (this.sheetType === 'category') {
        Text('选择分类')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .margin({ top: 20, bottom: 20 })

        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
          ForEach(CATEGORIES.filter((c: Category) => c.name !== '全部'), (cat: Category) => {
            Column() {
              Column()
                .width(40)
                .height(40)
                .backgroundColor(cat.color)
                .borderRadius(20)
                .margin({ bottom: 4 })
              Text(cat.name)
                .fontSize(12)
            }
            .width(80)
            .height(80)
            .margin(8)
            .borderRadius(12)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(this.selectedCategory === cat.name ? '#E6F7FF' : BG_COLOR_LIGHT)
            .onClick(() => {
              this.selectedCategory = cat.name
              this.showSheet = false
            })
          }, (cat: Category) => cat.name)
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      } else if (this.sheetType === 'mood') {
        Text('选择心情')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .margin({ top: 20, bottom: 20 })

        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
          ForEach(MOODS, (mood: string) => {
            Column() {
              Text(mood)
                .fontSize(32)
            }
            .width(64)
            .height(64)
            .margin(8)
            .borderRadius(12)
            .backgroundColor(this.selectedMood === mood ? '#E6F7FF' : BG_COLOR_LIGHT)
            .onClick(() => {
              this.selectedMood = this.selectedMood === mood ? '' : mood
              this.showSheet = false
            })
          }, (mood: string) => mood)
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TEXT_COLOR_WHITE)
  }
}
