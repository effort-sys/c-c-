// entry/src/main/ets/utils/DataManager.ets

import preferences from '@ohos.data.preferences'
import { DatabaseManager, UpdateNoteParams } from './DatabaseManager'
import { NoteEntity } from './DatabaseEntity'

const STORE_NAME = 'note_app_data'
const KEY_CURRENT_USER = 'currentUser'
const KEY_REMEMBER_LOGIN = 'rememberLogin'

// ========== 类型定义 ==========
export interface User {
  username: string
  password: string
  nickname: string
}

export interface Note {
  id: string
  userId: string
  authorNickname: string
  title: string
  content: string
  createTime: number
  updateTime: number
  isPinned: boolean
  category: string
  mood: string
  bgColor: string
  isDeleted: boolean
}

export interface Category {
  name: string
  color: string
}

// ========== 常量定义 ==========
export const CATEGORIES: Category[] = [
  { name: '全部', color: '#666666' },
  { name: '工作', color: '#4CAF50' },
  { name: '学习', color: '#2196F3' },
  { name: '生活', color: '#FF9800' },
  { name: '灵感', color: '#9C27B0' },
  { name: '其他', color: '#795548' }
]

export const MOODS: string[] = ['😊', '😢', '😡', '🤔', '😴', '💡', '❤️', '🎉']

export const BG_COLORS: string[] = [
  '#FFFFFF',
  '#FFF9C4',
  '#C8E6C9',
  '#BBDEFB',
  '#F8BBD9',
  '#FFE0B2',
  '#DCEDC8',
  '#D1C4E9'
]

export const DAILY_QUOTES: string[] = [
  '每天进步一点点，成功就在眼前！',
  '坚持就是胜利，加油！',
  '今天的努力，明天的收获。',
  '相信自己，你能行！',
  '每一次尝试，都是一次成长。',
  '保持热爱，奔赴山海。',
  '生活明朗，万物可爱。',
  '未来可期，人间值得。',
  '心若向阳，无畏悲伤。',
  '知足上进，不负野心。'
]

// ========== DataManager 类 ==========
export class DataManager {
  private static instance: DataManager
  private context: Context
  private dbManager: DatabaseManager

  private constructor(context: Context) {
    this.context = context
    this.dbManager = DatabaseManager.getInstance(context)
  }

  static getInstance(context: Context): DataManager {
    if (!DataManager.instance) {
      DataManager.instance = new DataManager(context)
    }
    return DataManager.instance
  }

  // ---------- 转换方法 ----------
  private toNoteEntity(note: Note): NoteEntity {
    return {
      id: note.id,
      userId: note.userId,
      authorNickname: note.authorNickname,
      title: note.title,
      content: note.content,
      createTime: note.createTime,
      updateTime: note.updateTime,
      isPinned: note.isPinned ? 1 : 0,
      category: note.category,
      mood: note.mood,
      bgColor: note.bgColor,
      isDeleted: note.isDeleted ? 1 : 0
    }
  }

  private toNote(entity: NoteEntity): Note {
    return {
      id: entity.id,
      userId: entity.userId,
      authorNickname: entity.authorNickname,
      title: entity.title,
      content: entity.content,
      createTime: entity.createTime,
      updateTime: entity.updateTime,
      isPinned: entity.isPinned === 1,
      category: entity.category,
      mood: entity.mood,
      bgColor: entity.bgColor,
      isDeleted: entity.isDeleted === 1
    }
  }

  // ---------- 用户相关方法 ----------
  async getUsers(): Promise<User[]> {
    const entities = await this.dbManager.getAllUsers()
    const users: User[] = []
    for (const e of entities) {
      users.push({
        username: e.username,
        password: e.password,
        nickname: e.nickname
      })
    }
    return users
  }

  async saveUsers(users: User[]): Promise<void> {
    for (const user of users) {
      const existing = await this.dbManager.getUser(user.username)
      if (!existing) {
        await this.dbManager.addUser(user.username, user.password, user.nickname)
      }
    }
  }

  async register(username: string, password: string, nickname: string = ''): Promise<boolean> {
    const finalNickname = nickname || username
    const existing = await this.dbManager.getUser(username)
    if (existing) {
      return false
    }
    return await this.dbManager.addUser(username, password, finalNickname)
  }

  async login(username: string, password: string): Promise<boolean> {
    const user = await this.dbManager.getUser(username)
    if (user && user.password === password) {
      await this.setCurrentUser(username)
      return true
    }
    return false
  }

  async setCurrentUser(username: string): Promise<void> {
    const prefs = await preferences.getPreferences(this.context, STORE_NAME)
    await prefs.put(KEY_CURRENT_USER, username)
    await prefs.flush()
  }

  async getCurrentUser(): Promise<string> {
    const prefs = await preferences.getPreferences(this.context, STORE_NAME)
    const value = await prefs.get(KEY_CURRENT_USER, '')
    return value as string
  }

  async setRememberLogin(remember: boolean): Promise<void> {
    const username = await this.getCurrentUser()
    if (username) {
      await this.dbManager.savePreference(username, remember ? 1 : 0, '', '')
    }
    const prefs = await preferences.getPreferences(this.context, STORE_NAME)
    await prefs.put(KEY_REMEMBER_LOGIN, remember)
    await prefs.flush()
  }

  async getRememberLogin(): Promise<boolean> {
    const prefs = await preferences.getPreferences(this.context, STORE_NAME)
    const prefValue = await prefs.get(KEY_REMEMBER_LOGIN, false)
    if (prefValue as boolean) {
      return prefValue as boolean
    }
    const username = await this.getCurrentUser()
    if (username) {
      const pref = await this.dbManager.getPreference(username)
      return pref ? pref.rememberLogin === 1 : false
    }
    return false
  }

  async logout(): Promise<void> {
    const username = await this.getCurrentUser()
    if (username) {
      await this.dbManager.savePreference(username, 0, '', '')
    }
    const prefs = await preferences.getPreferences(this.context, STORE_NAME)
    await prefs.put(KEY_CURRENT_USER, '')
    await prefs.put(KEY_REMEMBER_LOGIN, false)
    await prefs.flush()
  }

  async getUserNickname(username: string): Promise<string> {
    const user = await this.dbManager.getUser(username)
    return user?.nickname || username
  }

  async updateUserNickname(username: string, newNickname: string): Promise<boolean> {
    return await this.dbManager.updateUserNickname(username, newNickname)
  }

  // ---------- 笔记相关方法 ----------
  async getAllNotes(): Promise<Note[]> {
    const username = await this.getCurrentUser()
    const entities = await this.dbManager.getNotes(username, false)
    const notes: Note[] = []
    for (const e of entities) {
      notes.push(this.toNote(e))
    }
    return notes
  }

  async saveAllNotes(notes: Note[]): Promise<void> {
    // 数据库模式下此方法仅用于兼容
  }

  async getTrashNotes(): Promise<Note[]> {
    const username = await this.getCurrentUser()
    const entities = await this.dbManager.getTrashNotes(username)
    const notes: Note[] = []
    for (const e of entities) {
      notes.push(this.toNote(e))
    }
    return notes
  }

  async saveTrashNotes(notes: Note[]): Promise<void> {
    // 数据库模式下此方法仅用于兼容
  }

  async getUserNotes(username: string): Promise<Note[]> {
    const entities = await this.dbManager.getNotes(username, false)
    const notes: Note[] = []
    for (const e of entities) {
      notes.push(this.toNote(e))
    }
    return notes
  }

  async getUserTrashNotes(username: string): Promise<Note[]> {
    const entities = await this.dbManager.getTrashNotes(username)
    const notes: Note[] = []
    for (const e of entities) {
      notes.push(this.toNote(e))
    }
    return notes
  }

  async addNote(username: string, title: string, content: string, category: string = '其他', mood: string = '', bgColor: string = '#FFFFFF'): Promise<void> {
    const now = Date.now()
    const nickname = await this.getUserNickname(username)
    const note: Note = {
      id: now.toString(),
      userId: username,
      authorNickname: nickname,
      title: title,
      content: content,
      createTime: now,
      updateTime: now,
      isPinned: false,
      category: category,
      mood: mood,
      bgColor: bgColor,
      isDeleted: false
    }
    await this.dbManager.addNote(this.toNoteEntity(note))
  }

  async updateNote(noteId: string, title: string, content: string, category?: string, mood?: string, bgColor?: string): Promise<void> {
    const updates: UpdateNoteParams = {
      title: title,
      content: content,
      updateTime: Date.now()
    }
    if (category !== undefined) {
      updates.category = category
    }
    if (mood !== undefined) {
      updates.mood = mood
    }
    if (bgColor !== undefined) {
      updates.bgColor = bgColor
    }
    await this.dbManager.updateNote(noteId, updates)
  }

  async pinNote(noteId: string, isPinned: boolean): Promise<void> {
    const updates: UpdateNoteParams = {
      isPinned: isPinned ? 1 : 0,
      updateTime: Date.now()
    }
    await this.dbManager.updateNote(noteId, updates)
  }

  async deleteNote(noteId: string): Promise<void> {
    await this.dbManager.moveNoteToTrash(noteId)
  }

  async restoreNote(noteId: string): Promise<void> {
    await this.dbManager.restoreNote(noteId)
  }

  async permanentlyDeleteNote(noteId: string): Promise<void> {
    await this.dbManager.deleteNote(noteId)
  }

  async getDailyQuote(): Promise<string> {
    const username = await this.getCurrentUser()
    const today = new Date().toDateString()

    if (username) {
      const pref = await this.dbManager.getPreference(username)
      if (pref && pref.quoteDate === today && pref.dailyQuote) {
        return pref.dailyQuote
      }
    }

    const randomIndex = Math.floor(Math.random() * DAILY_QUOTES.length)
    const newQuote = DAILY_QUOTES[randomIndex]

    if (username) {
      const rememberLogin = await this.getRememberLogin()
      await this.dbManager.savePreference(username, rememberLogin ? 1 : 0, newQuote, today)
    }

    return newQuote
  }
}