import { ConfigurationConstant } from '@kit.AbilityKit';
import { PreferencesStore } from './PreferencesStore';
import { AppContextHolder } from '../core/AppContextHolder';

const STORE_NAME: string = 'harmony_appearance';
const KEY_MODE: string = 'color_mode';

export const APPEARANCE_SYSTEM: string = 'system';
export const APPEARANCE_LIGHT: string = 'light';
export const APPEARANCE_DARK: string = 'dark';

/**
 * 外观模式：跟随系统 / 浅色 / 深色。
 * 通过 ApplicationContext.setColorMode 生效，选择持久化到 preferences。
 */
export class AppearanceStore {
  private store: PreferencesStore | null = null;

  private async storeOf(): Promise<PreferencesStore> {
    if (this.store === null) {
      this.store = new PreferencesStore(AppContextHolder.require(), STORE_NAME);
    }
    return this.store;
  }

  async load(): Promise<string> {
    try {
      const store: PreferencesStore = await this.storeOf();
      const value: string = await store.getString(KEY_MODE);
      return value.length > 0 ? value : APPEARANCE_SYSTEM;
    } catch (error) {
      return APPEARANCE_SYSTEM;
    }
  }

  async apply(mode: string): Promise<void> {
    const context = AppContextHolder.require().getApplicationContext();
    const colorMode: ConfigurationConstant.ColorMode =
      mode === APPEARANCE_DARK ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK :
        mode === APPEARANCE_LIGHT ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT :
          ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    context.setColorMode(colorMode);
    try {
      const store: PreferencesStore = await this.storeOf();
      await store.putString(KEY_MODE, mode);
    } catch (error) {
      // 持久化失败不影响本次生效
    }
  }

  async restore(): Promise<void> {
    await this.apply(await this.load());
  }
}
