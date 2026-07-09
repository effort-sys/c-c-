// entry/src/main/ets/pages/NoteList.ets

import { DataManager, Note, Category, CATEGORIES, MOODS, BG_COLORS, DAILY_QUOTES } from '../utils/DataManager'
import router from '@ohos.router'
import promptAction from '@ohos.promptAction'

const PRIMARY_COLOR = '#007DFF'
const BG_COLOR_LIGHT = '#F5F5F5'
const BG_COLOR_PAGE = '#F0F0F0'
const TEXT_COLOR_PRIMARY = '#333333'
const TEXT_COLOR_SECONDARY = '#666666'
const TEXT_COLOR_TERTIARY = '#999999'
const TEXT_COLOR_WHITE = '#FFFFFF'
const TEXT_COLOR_DANGER = '#FF4D4F'
const TEXT_COLOR_SUCCESS = '#52C41A'

@Entry
@Component
struct NoteList {
  @State notes: Note[] = []
  @State allNotes: Note[] = []
  @State trashNotes: Note[] = []
  @State isReversed: boolean = false
  @State currentUser: string = ''
  @State userNickname: string = ''
  @State searchText: string = ''
  @State selectedCategory: string = '全部'
  @State showTrash: boolean = false
  @State dailyQuote: string = ''
  @State showRandomNote: boolean = false
  @State randomNote: Note | null = null
  private dataManager: DataManager | null = null

  aboutToAppear() {
    this.dataManager = DataManager.getInstance(getContext(this))
    this.loadData()
  }

  onPageShow() {
    this.loadData()
  }

  async loadData() {
    if (this.dataManager) {
      this.currentUser = await this.dataManager.getCurrentUser()
      this.userNickname = await this.dataManager.getUserNickname(this.currentUser)
      this.allNotes = await this.dataManager.getUserNotes(this.currentUser)
      this.trashNotes = await this.dataManager.getUserTrashNotes(this.currentUser)
      this.dailyQuote = await this.dataManager.getDailyQuote()
      this.filterNotes()
    }
  }

  filterNotes() {
    let filteredNotes = this.showTrash ? this.trashNotes : this.allNotes

    if (!this.showTrash && this.selectedCategory !== '全部') {
      filteredNotes = filteredNotes.filter(note => note.category === this.selectedCategory)
    }

    if (this.searchText.trim()) {
      const search = this.searchText.toLowerCase()
      filteredNotes = filteredNotes.filter(note =>
      note.title.toLowerCase().includes(search) ||
        note.content.toLowerCase().includes(search)
      )
    }

    if (!this.showTrash) {
      filteredNotes.sort((a, b) => {
        if (a.isPinned && !b.isPinned) return -1
        if (!a.isPinned && b.isPinned) return 1
        const timeDiff = b.updateTime - a.updateTime
        return this.isReversed ? -timeDiff : timeDiff
      })
    } else {
      filteredNotes.sort((a, b) => b.updateTime - a.updateTime)
    }

    this.notes = filteredNotes
  }

  toggleOrder() {
    this.isReversed = !this.isReversed
    this.filterNotes()
  }

  // 新建文字笔记
  addNote() {
    router.pushUrl({ url: 'pages/NoteEdit' })
  }

  // 新建语音笔记
  addVoiceNote() {
    router.pushUrl({ url: 'pages/VoiceNoteRecorder' })
  }

  editNote(note: Note) {
    if (this.showTrash) return
    router.pushUrl({
      url: 'pages/NoteEdit',
      params: {
        noteId: note.id,
        title: note.title,
        content: note.content,
        note: note
      }
    })
  }

  async deleteNote(noteId: string) {
    if (this.showTrash) return
    promptAction.showDialog({
      title: '提示',
      message: '确定要删除这条笔记吗？',
      buttons: [
        { text: '取消', color: '#666666' },
        { text: '删除', color: '#FF4D4F' }
      ]
    }).then(async (result) => {
      if (result.index === 1 && this.dataManager) {
        await this.dataManager.deleteNote(noteId)
        await this.loadData()
        promptAction.showToast({ message: '已移到回收站' })
      }
    })
  }

  async restoreNote(noteId: string) {
    if (!this.showTrash) return
    if (this.dataManager) {
      await this.dataManager.restoreNote(noteId)
      await this.loadData()
      promptAction.showToast({ message: '已恢复' })
    }
  }

  async permanentlyDeleteNote(noteId: string) {
    if (!this.showTrash) return
    promptAction.showDialog({
      title: '提示',
      message: '确定要永久删除这条笔记吗？删除后无法恢复！',
      buttons: [
        { text: '取消', color: '#666666' },
        { text: '删除', color: '#FF4D4F' }
      ]
    }).then(async (result) => {
      if (result.index === 1 && this.dataManager) {
        await this.dataManager.permanentlyDeleteNote(noteId)
        await this.loadData()
        promptAction.showToast({ message: '已永久删除' })
      }
    })
  }

  async togglePin(noteId: string, currentPin: boolean) {
    if (this.showTrash) return
    if (this.dataManager) {
      await this.dataManager.pinNote(noteId, !currentPin)
      await this.loadData()
      promptAction.showToast({ message: currentPin ? '已取消置顶' : '已置顶' })
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

  showRandomNoteDialog() {
    if (this.allNotes.length === 0) {
      promptAction.showToast({ message: '还没有笔记' })
      return
    }
    const randomIndex = Math.floor(Math.random() * this.allNotes.length)
    this.randomNote = this.allNotes[randomIndex]
    this.showRandomNote = true
  }

  formatTime(timestamp: number): string {
    const date = new Date(timestamp)
    const year = date.getFullYear()
    const month = (date.getMonth() + 1).toString().padStart(2, '0')
    const day = date.getDate().toString().padStart(2, '0')
    const hour = date.getHours().toString().padStart(2, '0')
    const minute = date.getMinutes().toString().padStart(2, '0')
    return `${year}-${month}-${day} ${hour}:${minute}`
  }

  getContentPreview(content: string): string {
    if (content.length <= 50) {
      return content
    }
    return content.substring(0, 50) + '...'
  }

  getCategoryColor(category: string): string {
    const cat = CATEGORIES.find(c => c.name === category)
    return cat ? cat.color : '#666666'
  }

  getWordCount(note: Note): number {
    return note.title.length + note.content.length
  }

  build() {
    Column() {
      this.buildHeader()

      if (!this.showTrash) {
        this.buildFilterSection()
      }

      this.buildContentSection()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(BG_COLOR_PAGE)
    .bindSheet(this.showRandomNote, this.randomNote ? this.buildRandomNoteSheet() : null, {
      height: 400,
      dragBar: true,
      onDisappear: () => {
        this.showRandomNote = false
      }
    })
  }

  @Builder
  buildHeader() {
    Row() {
      // 左侧：设置/返回按钮
      Button() {
        Image(this.showTrash ? $r('app.media.tui') : $r('app.media.shezhi'))
          .width(22)
          .height(22)
          .objectFit(ImageFit.Contain)
      }
      .type(ButtonType.Circle)
      .width(40)
      .height(40)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        if (this.showTrash) {
          this.showTrash = false
          this.filterNotes()
        } else {
          router.pushUrl({ url: 'pages/Settings' })
        }
      })

      // 标题
      Text(this.showTrash ? '回收站' : '语音备忘录')
        .layoutWeight(1)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .textAlign(TextAlign.Center)

      // 右侧按钮组（只在非回收站模式显示）
      if (!this.showTrash) {
        // 1. 随机笔记按钮
        Button() {
          Image($r('app.media.touzi'))
            .width(22)
            .height(22)
            .objectFit(ImageFit.Contain)
        }
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.showRandomNoteDialog()
        })

        // 2. 排序按钮
        Button() {
          Image(this.isReversed ? $r('app.media.sheng') : $r('app.media.jiang'))
            .width(22)
            .height(22)
            .objectFit(ImageFit.Contain)
        }
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.toggleOrder()
        })

        // 3. 语音备忘录按钮（新增）
        Button() {
          Image($r('app.media.03'))  // 使用麦克风图标，您需要确保有这张图片
            .width(22)
            .height(22)
            .objectFit(ImageFit.Contain)
        }
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.addVoiceNote()
        })

        // 4. 新建笔记按钮
        Button() {
          Image($r('app.media.jia'))
            .width(24)
            .height(24)
            .objectFit(ImageFit.Contain)
        }
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.addNote()
        })
      } else {
        // 回收站模式：返回按钮
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
          this.showTrash = !this.showTrash
          this.filterNotes()
        })
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: 10, right: 10 })
    .backgroundColor(TEXT_COLOR_WHITE)
  }

  @Builder
  buildFilterSection() {
    Column({ space: 8 }) {
      // 每日一言
      Column() {
        Text(this.dailyQuote)
          .fontSize(13)
          .fontColor(TEXT_COLOR_WHITE)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .backgroundColor(PRIMARY_COLOR)
      .borderRadius(8)
      .onClick(() => {
        const randomIndex = Math.floor(Math.random() * DAILY_QUOTES.length)
        this.dailyQuote = DAILY_QUOTES[randomIndex]
      })

      // 搜索框
      TextInput({ placeholder: '搜索笔记...', text: this.searchText })
        .width('100%')
        .height(43)
        .backgroundColor(BG_COLOR_LIGHT)
        .borderRadius(6)
        .border({
          width: 1,
          color: '#E0E0E0'
        })
        .padding({ left: 18, right: 18 })
        .onChange((value: string) => {
          this.searchText = value
          this.filterNotes()
        })

      // 分类标签
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(CATEGORIES, (cat: Category) => {
          Button(cat.name)
            .height(26)
            .borderRadius(13)
            .fontSize(12)
            .backgroundColor(this.selectedCategory === cat.name ? cat.color : BG_COLOR_LIGHT)
            .fontColor(this.selectedCategory === cat.name ? TEXT_COLOR_WHITE : TEXT_COLOR_SECONDARY)
            .margin({ right: 5, bottom: 5 })
            .onClick(() => {
              this.selectedCategory = cat.name
              this.filterNotes()
            })
        })
      }
      .width('100%')

      // 底部统计
      Row() {
        Text(`共 ${this.notes.length} 条笔记`)
          .fontSize(11)
          .fontColor(TEXT_COLOR_TERTIARY)

        Blank()

        // 快速语音入口（新增）
        Button() {
          Row({ space: 4 }) {
            Text('🎙️')
              .fontSize(14)
            Text('语音')
              .fontSize(11)
          }
        }
        .height(24)
        .borderRadius(12)
        .fontSize(11)
        .backgroundColor(PRIMARY_COLOR + '20')
        .fontColor(PRIMARY_COLOR)
        .onClick(() => {
          this.addVoiceNote()
        })

        Button('回收站')
          .height(24)
          .borderRadius(12)
          .fontSize(11)
          .backgroundColor(BG_COLOR_LIGHT)
          .fontColor(TEXT_COLOR_SECONDARY)
          .margin({ left: 8 })
          .onClick(() => {
            this.showTrash = true
            this.filterNotes()
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 6, bottom: 6 })
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  buildContentSection() {
    if (this.notes.length === 0) {
      Column() {
        Image($r('app.media.02'))
          .width(120)
          .height(120)
          .objectFit(ImageFit.Contain)
          .margin({ bottom: 16 })

        Text(this.showTrash ? '回收站是空的' : '暂无笔记')
          .fontSize(16)
          .fontColor(TEXT_COLOR_TERTIARY)
          .margin({ bottom: 8 })

        if (!this.showTrash) {
          Row({ space: 16 }) {
            Button() {
              Row({ space: 6 }) {
                Text('✏️')
                  .fontSize(16)
                Text('文字')
                  .fontSize(14)
              }
            }
            .height(40)
            .padding({ left: 20, right: 20 })
            .backgroundColor(PRIMARY_COLOR)
            .borderRadius(20)
            .fontColor(TEXT_COLOR_WHITE)
            .onClick(() => {
              this.addNote()
            })

            Button() {
              Row({ space: 6 }) {
                Text('🎙️')
                  .fontSize(16)
                Text('语音')
                  .fontSize(14)
              }
            }
            .height(40)
            .padding({ left: 20, right: 20 })
            .backgroundColor('#FF6B6B')
            .borderRadius(20)
            .fontColor(TEXT_COLOR_WHITE)
            .onClick(() => {
              this.addVoiceNote()
            })
          }
        }
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      List() {
        ForEach(this.notes, (note: Note) => {
          ListItem() {
            this.buildNoteItem(note)
          }
          .margin({ left: 14, right: 14, top: 5, bottom: 5 })
        })
      }
      .layoutWeight(1)
      .width('100%')
    }
  }

  @Builder
  buildNoteItem(note: Note) {
    Column() {
      this.buildNoteTitle(note)
      this.buildNoteContent(note)
      this.buildNoteMeta(note)
      this.buildNoteActions(note)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor(note.bgColor || TEXT_COLOR_WHITE)
    .borderRadius(8)
    .onClick(() => {
      this.editNote(note)
    })
  }

  @Builder
  buildNoteTitle(note: Note) {
    Row() {
      if (note.isPinned && !this.showTrash) {
        Text('📌')
          .fontSize(13)
          .margin({ right: 5 })
      }
      if (note.mood && !this.showTrash) {
        Text(note.mood)
          .fontSize(13)
          .margin({ right: 5 })
      }
      // 语音笔记标识
      if (note.category === '语音' && !this.showTrash) {
        Text('🎙️')
          .fontSize(13)
          .margin({ right: 5 })
      }
      Text(note.title || '无标题')
        .layoutWeight(1)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(TEXT_COLOR_PRIMARY)
        .textAlign(TextAlign.Start)
    }
    .width('100%')
    .margin({ bottom: 5 })
  }

  @Builder
  buildNoteContent(note: Note) {
    Text(this.getContentPreview(note.content))
      .width('100%')
      .fontSize(12)
      .fontColor(TEXT_COLOR_SECONDARY)
      .margin({ bottom: 6 })
      .textAlign(TextAlign.Start)
      .maxLines(2)
  }

  @Builder
  buildNoteMeta(note: Note) {
    Row() {
      if (!this.showTrash) {
        Text(note.category)
          .fontSize(10)
          .fontColor(TEXT_COLOR_WHITE)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor(this.getCategoryColor(note.category))
          .borderRadius(7)
      }
      Blank()

      if (note.authorNickname) {
        Text(note.authorNickname)
          .fontSize(10)
          .fontColor(TEXT_COLOR_SECONDARY)
          .margin({ right: 8 })
      }

      Text(`${this.getWordCount(note)}字`)
        .fontSize(10)
        .fontColor(TEXT_COLOR_TERTIARY)
        .margin({ right: 8 })
      Text(this.formatTime(note.updateTime))
        .fontSize(10)
        .fontColor(TEXT_COLOR_TERTIARY)
    }
    .width('100%')
  }

  @Builder
  buildNoteActions(note: Note) {
    if (!this.showTrash) {
      Row({ space: 10 }) {
        Button(note.isPinned ? '取消置顶' : '置顶')
          .height(26)
          .borderRadius(5)
          .fontSize(12)
          .backgroundColor(BG_COLOR_LIGHT)
          .fontColor(TEXT_COLOR_SECONDARY)
          .onClick(() => {
            this.togglePin(note.id, note.isPinned)
          })

        Button('删除')
          .height(26)
          .borderRadius(5)
          .fontSize(12)
          .backgroundColor('#FFF0F0')
          .fontColor(TEXT_COLOR_DANGER)
          .onClick(() => {
            this.deleteNote(note.id)
          })
      }
      .width('100%')
      .margin({ top: 8 })
    } else {
      Row({ space: 10 }) {
        Button('恢复')
          .height(26)
          .borderRadius(5)
          .fontSize(12)
          .backgroundColor('#F0FFF0')
          .fontColor(TEXT_COLOR_SUCCESS)
          .onClick(() => {
            this.restoreNote(note.id)
          })

        Button('永久删除')
          .height(26)
          .borderRadius(5)
          .fontSize(12)
          .backgroundColor('#FFF0F0')
          .fontColor(TEXT_COLOR_DANGER)
          .onClick(() => {
            this.permanentlyDeleteNote(note.id)
          })
      }
      .width('100%')
      .margin({ top: 8 })
    }
  }

  @Builder
  buildRandomNoteSheet() {
    if (this.randomNote) {
      Scroll() {
        Column({ space: 16 }) {
          Row() {
            if (this.randomNote.mood) {
              Text(this.randomNote.mood)
                .fontSize(24)
                .margin({ right: 8 })
            }
            Text(this.randomNote.title || '无标题')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
          }
          .width('100%')

          Text(this.randomNote.content)
            .fontSize(16)
            .fontColor(TEXT_COLOR_SECONDARY)
            .width('100%')

          Row() {
            Text(this.randomNote.category)
              .fontSize(12)
              .fontColor(TEXT_COLOR_WHITE)
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
              .backgroundColor(this.getCategoryColor(this.randomNote.category))
              .borderRadius(10)
            Blank()
            Text(this.formatTime(this.randomNote.updateTime))
              .fontSize(12)
              .fontColor(TEXT_COLOR_TERTIARY)
          }
          .width('100%')

          Button('编辑')
            .width('100%')
            .height(44)
            .backgroundColor(PRIMARY_COLOR)
            .borderRadius(8)
            .fontSize(16)
            .onClick(() => {
              this.showRandomNote = false
              this.editNote(this.randomNote!)
            })
        }
        .width('100%')
        .padding(16)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.randomNote.bgColor || TEXT_COLOR_WHITE)
    }
  }
}