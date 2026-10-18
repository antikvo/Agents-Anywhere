import { preferences } from '@kit.ArkData';
import { AppContextHolder } from '../core/AppContextHolder';

const STORE_NAME: string = 'harmony_deeplink';
const KEY_PENDING: string = 'pendingSessionId';

async function openStore(): Promise<preferences.Preferences> {
  return await preferences.getPreferences(AppContextHolder.require(), STORE_NAME);
}

export async function setPendingSession(sessionId: string): Promise<void> {
  try {
    const store: preferences.Preferences = await openStore();
    await store.put(KEY_PENDING, sessionId);
    await store.flush();
  } catch (error) {
    // 深链失败不应影响正常启动
  }
}

export async function takePendingSession(): Promise<string> {
  try {
    const store: preferences.Preferences = await openStore();
    const value: preferences.ValueType = await store.get(KEY_PENDING, '');
    const sessionId: string = typeof value === 'string' ? value as string : '';
    if (sessionId.length > 0) {
      await store.delete(KEY_PENDING);
      await store.flush();
    }
    return sessionId;
  } catch (error) {
    return '';
  }
}
