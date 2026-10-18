import { PreferencesStore } from './PreferencesStore';
import { AppContextHolder } from '../core/AppContextHolder';

const STORE_NAME: string = 'harmony_cache';

/**
 * 轻量离线缓存：把 JSON 字符串写入 preferences，网络不可用时回退展示。
 * 只缓存首屏/最近数据，不做完整离线库。
 */
export class CacheStore {
  private store: PreferencesStore | null = null;

  private async storeOf(): Promise<PreferencesStore> {
    if (this.store === null) {
      this.store = new PreferencesStore(AppContextHolder.require(), STORE_NAME);
    }
    return this.store;
  }

  async save(key: string, json: string): Promise<void> {
    try {
      const store: PreferencesStore = await this.storeOf();
      await store.putString(key, json);
      await store.putString(`${key}_at`, new Date().toISOString());
    } catch (error) {
      // 缓存失败不影响主流程
    }
  }

  async load(key: string): Promise<string> {
    try {
      const store: PreferencesStore = await this.storeOf();
      return await store.getString(key);
    } catch (error) {
      return '';
    }
  }

  async savedAt(key: string): Promise<string> {
    try {
      const store: PreferencesStore = await this.storeOf();
      return await store.getString(`${key}_at`);
    } catch (error) {
      return '';
    }
  }

  async clear(key: string): Promise<void> {
    try {
      const store: PreferencesStore = await this.storeOf();
      await store.remove(key);
      await store.remove(`${key}_at`);
    } catch (error) {
      // 忽略
    }
  }
}
