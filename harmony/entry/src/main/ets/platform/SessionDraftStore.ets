import { PreferencesStore } from './PreferencesStore';
import { AppContextHolder } from '../core/AppContextHolder';

const STORE_NAME: string = 'harmony_session_drafts';

/**
 * 按会话保存输入框草稿：离开页面后再次进入可以继续编辑。
 */
export class SessionDraftStore {
  private store: PreferencesStore | null = null;

  private async storeOf(): Promise<PreferencesStore> {
    if (this.store === null) {
      this.store = new PreferencesStore(AppContextHolder.require(), STORE_NAME);
    }
    return this.store;
  }

  async load(sessionId: string): Promise<string> {
    if (sessionId.length === 0) {
      return '';
    }
    try {
      const store: PreferencesStore = await this.storeOf();
      return await store.getString(`draft_${sessionId}`);
    } catch (error) {
      return '';
    }
  }

  async save(sessionId: string, text: string): Promise<void> {
    if (sessionId.length === 0) {
      return;
    }
    try {
      const store: PreferencesStore = await this.storeOf();
      if (text.trim().length === 0) {
        await store.remove(`draft_${sessionId}`);
      } else {
        await store.putString(`draft_${sessionId}`, text);
      }
    } catch (error) {
      // 草稿失败不影响主流程
    }
  }

  async clear(sessionId: string): Promise<void> {
    await this.save(sessionId, '');
  }
}
