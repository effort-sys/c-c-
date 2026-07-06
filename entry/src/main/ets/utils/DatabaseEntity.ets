// entry/src/main/ets/utils/DatabaseEntity.ets

export interface UserEntity {
  id: number
  username: string
  password: string
  nickname: string
  createTime: number
}

export interface NoteEntity {
  id: string
  userId: string
  authorNickname: string
  title: string
  content: string
  createTime: number
  updateTime: number
  isPinned: number
  category: string
  mood: string
  bgColor: string
  isDeleted: number
}

export interface UserPreferenceEntity {
  id: number
  userId: string
  rememberLogin: number
  dailyQuote: string
  quoteDate: string
}