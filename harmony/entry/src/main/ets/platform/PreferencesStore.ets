import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

/**
 * preferences 的异步封装。
 *
 * 当前用于保存服务器地址与登录 token；签名/真机阶段替换为 HUKS 加密实现，
 * 见 docs/harmony-client-plan.md 的 M0 任务。
 */
export class PreferencesStore {
  private readonly context: common.Context;
  private readonly name: string;
  private instance: preferences.Preferences | null = null;

  constructor(context: common.Context, name: string) {
    this.context = context;
    this.name = name;
  }

  private async ensureInstance(): Promise<preferences.Preferences> {
    if (this.instance === null) {
      this.instance = await preferences.getPreferences(this.context, this.name);
    }
    return this.instance;
  }

  async getString(key: string, fallback: string = ''): Promise<string> {
    const store: preferences.Preferences = await this.ensureInstance();
    const value: preferences.ValueType = await store.get(key, fallback);
    return typeof value === 'string' ? value as string : fallback;
  }

  async putString(key: string, value: string): Promise<void> {
    const store: preferences.Preferences = await this.ensureInstance();
    await store.put(key, value);
    await store.flush();
  }

  async remove(key: string): Promise<void> {
    const store: preferences.Preferences = await this.ensureInstance();
    await store.delete(key);
    await store.flush();
  }
}
