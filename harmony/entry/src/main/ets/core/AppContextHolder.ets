import { common } from '@kit.AbilityKit';

/**
 * 保存应用级 Context，供 preferences 等需要 Context 的能力使用。
 * 在 EntryAbility.onCreate 中初始化。
 */
export class AppContextHolder {
  private static context: common.Context | null = null;

  static init(context: common.Context): void {
    AppContextHolder.context = context;
  }

  static require(): common.Context {
    const context: common.Context | null = AppContextHolder.context;
    if (context === null) {
      throw new Error('AppContextHolder has not been initialized.');
    }
    return context;
  }
}
