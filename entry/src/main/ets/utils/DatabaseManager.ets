// entry/src/main/ets/utils/DatabaseManager.ets

import relationalStore from '@ohos.data.relationalStore'
import { UserEntity, NoteEntity, UserPreferenceEntity } from './DatabaseEntity'

const DB_NAME = 'note_app.db'

export class DatabaseManager {
  private static instance: DatabaseManager
  private store: relationalStore.RdbStore | null = null
  private context: Context

  private constructor(context: Context) {
    this.context = context
  }

  static getInstance(context: Context): DatabaseManager {
    if (!DatabaseManager.instance) {
      DatabaseManager.instance = new DatabaseManager(context)
    }
    return DatabaseManager.instance
  }

  private async getStore(): Promise<relationalStore.RdbStore> {
    if (this.store) {
      return this.store
    }

    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    }

    this.store = await relationalStore.getRdbStore(this.context, config)
    await this.createTables()
    return this.store
  }

  private async createTables(): Promise<void> {
    const store = await this.getStore()

    await store.executeSql(`
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        nickname TEXT NOT NULL,
        createTime INTEGER NOT NULL
      )
    `)

    await store.executeSql(`
      CREATE TABLE IF NOT EXISTS notes (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        authorNickname TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        createTime INTEGER NOT NULL,
        updateTime INTEGER NOT NULL,
        isPinned INTEGER NOT NULL DEFAULT 0,
        category TEXT NOT NULL DEFAULT '其他',
        mood TEXT NOT NULL DEFAULT '',
        bgColor TEXT NOT NULL DEFAULT '#FFFFFF',
        isDeleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (userId) REFERENCES users(username) ON DELETE CASCADE
      )
    `)

    await store.executeSql(`
      CREATE TABLE IF NOT EXISTS user_preferences (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT NOT NULL UNIQUE,
        rememberLogin INTEGER NOT NULL DEFAULT 0,
        dailyQuote TEXT NOT NULL DEFAULT '',
        quoteDate TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (userId) REFERENCES users(username) ON DELETE CASCADE
      )
    `)

    await store.executeSql(`
      CREATE INDEX IF NOT EXISTS idx_notes_userId ON notes(userId)
    `)
    await store.executeSql(`
      CREATE INDEX IF NOT EXISTS idx_notes_updateTime ON notes(updateTime)
    `)
    await store.executeSql(`
      CREATE INDEX IF NOT EXISTS idx_notes_isDeleted ON notes(isDeleted)
    `)
  }

  // ==================== 用户操作 ====================

  async addUser(username: string, password: string, nickname: string): Promise<boolean> {
    try {
      const store = await this.getStore()
      const insertSql = `INSERT INTO users (username, password, nickname, createTime) VALUES (?, ?, ?, ?)`
      const now = Date.now()
      await store.executeSql(insertSql, [username, password, nickname, now])
      return true
    } catch (e) {
      console.error('addUser error:', e)
      return false
    }
  }

  async getUser(username: string): Promise<UserEntity | null> {
    try {
      const store = await this.getStore()
      const resultSet = await store.querySql(`SELECT * FROM users WHERE username = ?`, [username])
      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow()
        const user: UserEntity = {
          id: resultSet.getLong(0),
          username: resultSet.getString(1),
          password: resultSet.getString(2),
          nickname: resultSet.getString(3),
          createTime: resultSet.getLong(4)
        }
        resultSet.close()
        return user
      }
      resultSet.close()
      return null
    } catch (e) {
      console.error('getUser error:', e)
      return null
    }
  }

  async getAllUsers(): Promise<UserEntity[]> {
    try {
      const store = await this.getStore()
      const resultSet = await store.querySql(`SELECT * FROM users ORDER BY createTime ASC`)
      const users: UserEntity[] = []
      while (resultSet.goToNextRow()) {
        users.push({
          id: resultSet.getLong(0),
          username: resultSet.getString(1),
          password: resultSet.getString(2),
          nickname: resultSet.getString(3),
          createTime: resultSet.getLong(4)
        })
      }
      resultSet.close()
      return users
    } catch (e) {
      console.error('getAllUsers error:', e)
      return []
    }
  }

  async updateUserNickname(username: string, nickname: string): Promise<boolean> {
    try {
      const store = await this.getStore()
      const updateSql = `UPDATE users SET nickname = ? WHERE username = ?`
      await store.executeSql(updateSql, [nickname, username])

      const updateNotesSql = `UPDATE notes SET authorNickname = ? WHERE userId = ?`
      await store.executeSql(updateNotesSql, [nickname, username])
      return true
    } catch (e) {
      console.error('updateUserNickname error:', e)
      return false
    }
  }

  // ==================== 笔记操作 ====================

  async addNote(note: NoteEntity): Promise<boolean> {
    try {
      const store = await this.getStore()
      const insertSql = `
        INSERT INTO notes (id, userId, authorNickname, title, content, createTime, updateTime, isPinned, category, mood, bgColor, isDeleted)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `
      await store.executeSql(insertSql, [
        note.id,
        note.userId,
        note.authorNickname,
        note.title,
        note.content,
        note.createTime,
        note.updateTime,
        note.isPinned,
        note.category,
        note.mood,
        note.bgColor,
        note.isDeleted
      ])
      return true
    } catch (e) {
      console.error('addNote error:', e)
      return false
    }
  }

  async getNotes(userId: string, includeDeleted: boolean = false): Promise<NoteEntity[]> {
    try {
      const store = await this.getStore()
      const sql = includeDeleted
        ? `SELECT * FROM notes WHERE userId = ? ORDER BY updateTime DESC`
        : `SELECT * FROM notes WHERE userId = ? AND isDeleted = 0 ORDER BY updateTime DESC`
      const resultSet = await store.querySql(sql, [userId])
      const notes: NoteEntity[] = []
      while (resultSet.goToNextRow()) {
        notes.push({
          id: resultSet.getString(0),
          userId: resultSet.getString(1),
          authorNickname: resultSet.getString(2),
          title: resultSet.getString(3),
          content: resultSet.getString(4),
          createTime: resultSet.getLong(5),
          updateTime: resultSet.getLong(6),
          isPinned: resultSet.getLong(7),
          category: resultSet.getString(8),
          mood: resultSet.getString(9),
          bgColor: resultSet.getString(10),
          isDeleted: resultSet.getLong(11)
        })
      }
      resultSet.close()
      return notes
    } catch (e) {
      console.error('getNotes error:', e)
      return []
    }
  }

  async getTrashNotes(userId: string): Promise<NoteEntity[]> {
    try {
      const store = await this.getStore()
      const sql = `SELECT * FROM notes WHERE userId = ? AND isDeleted = 1 ORDER BY updateTime DESC`
      const resultSet = await store.querySql(sql, [userId])
      const notes: NoteEntity[] = []
      while (resultSet.goToNextRow()) {
        notes.push({
          id: resultSet.getString(0),
          userId: resultSet.getString(1),
          authorNickname: resultSet.getString(2),
          title: resultSet.getString(3),
          content: resultSet.getString(4),
          createTime: resultSet.getLong(5),
          updateTime: resultSet.getLong(6),
          isPinned: resultSet.getLong(7),
          category: resultSet.getString(8),
          mood: resultSet.getString(9),
          bgColor: resultSet.getString(10),
          isDeleted: resultSet.getLong(11)
        })
      }
      resultSet.close()
      return notes
    } catch (e) {
      console.error('getTrashNotes error:', e)
      return []
    }
  }

  async updateNote(noteId: string, updates: UpdateNoteParams): Promise<boolean> {
    try {
      const store = await this.getStore()
      const fields: string[] = []
      const values: (string | number)[] = []

      if (updates.title !== undefined) { fields.push('title = ?'); values.push(updates.title) }
      if (updates.content !== undefined) { fields.push('content = ?'); values.push(updates.content) }
      if (updates.authorNickname !== undefined) { fields.push('authorNickname = ?'); values.push(updates.authorNickname) }
      if (updates.updateTime !== undefined) { fields.push('updateTime = ?'); values.push(updates.updateTime) }
      if (updates.isPinned !== undefined) { fields.push('isPinned = ?'); values.push(updates.isPinned) }
      if (updates.category !== undefined) { fields.push('category = ?'); values.push(updates.category) }
      if (updates.mood !== undefined) { fields.push('mood = ?'); values.push(updates.mood) }
      if (updates.bgColor !== undefined) { fields.push('bgColor = ?'); values.push(updates.bgColor) }
      if (updates.isDeleted !== undefined) { fields.push('isDeleted = ?'); values.push(updates.isDeleted) }

      if (fields.length === 0) return true

      values.push(noteId)
      const sql = `UPDATE notes SET ${fields.join(', ')} WHERE id = ?`
      await store.executeSql(sql, values)
      return true
    } catch (e) {
      console.error('updateNote error:', e)
      return false
    }
  }

  async deleteNote(noteId: string): Promise<boolean> {
    try {
      const store = await this.getStore()
      await store.executeSql(`DELETE FROM notes WHERE id = ?`, [noteId])
      return true
    } catch (e) {
      console.error('deleteNote error:', e)
      return false
    }
  }

  async moveNoteToTrash(noteId: string): Promise<boolean> {
    const updates: UpdateNoteParams = {
      isDeleted: 1,
      updateTime: Date.now()
    }
    return this.updateNote(noteId, updates)
  }

  async restoreNote(noteId: string): Promise<boolean> {
    const updates: UpdateNoteParams = {
      isDeleted: 0,
      updateTime: Date.now()
    }
    return this.updateNote(noteId, updates)
  }

  // ==================== 用户偏好操作 ====================

  async getPreference(userId: string): Promise<UserPreferenceEntity | null> {
    try {
      const store = await this.getStore()
      const resultSet = await store.querySql(`SELECT * FROM user_preferences WHERE userId = ?`, [userId])
      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow()
        const pref: UserPreferenceEntity = {
          id: resultSet.getLong(0),
          userId: resultSet.getString(1),
          rememberLogin: resultSet.getLong(2),
          dailyQuote: resultSet.getString(3),
          quoteDate: resultSet.getString(4)
        }
        resultSet.close()
        return pref
      }
      resultSet.close()
      return null
    } catch (e) {
      console.error('getPreference error:', e)
      return null
    }
  }

  async savePreference(userId: string, rememberLogin: number, dailyQuote: string, quoteDate: string): Promise<boolean> {
    try {
      const store = await this.getStore()
      const existing = await this.getPreference(userId)
      if (existing) {
        const sql = `UPDATE user_preferences SET rememberLogin = ?, dailyQuote = ?, quoteDate = ? WHERE userId = ?`
        await store.executeSql(sql, [rememberLogin, dailyQuote, quoteDate, userId])
      } else {
        const sql = `INSERT INTO user_preferences (userId, rememberLogin, dailyQuote, quoteDate) VALUES (?, ?, ?, ?)`
        await store.executeSql(sql, [userId, rememberLogin, dailyQuote, quoteDate])
      }
      return true
    } catch (e) {
      console.error('savePreference error:', e)
      return false
    }
  }

  async deletePreference(userId: string): Promise<boolean> {
    try {
      const store = await this.getStore()
      await store.executeSql(`DELETE FROM user_preferences WHERE userId = ?`, [userId])
      return true
    } catch (e) {
      console.error('deletePreference error:', e)
      return false
    }
  }
}

// 更新参数接口（不使用 utility types）
export interface UpdateNoteParams {
  title?: string
  content?: string
  authorNickname?: string
  updateTime?: number
  isPinned?: number
  category?: string
  mood?: string
  bgColor?: string
  isDeleted?: number
}