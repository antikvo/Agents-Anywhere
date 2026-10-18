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

const KEY_MOBILE_USER: string = 'pendingMobileUser';
const KEY_MOBILE_TOKEN: string = 'pendingMobileToken';
const KEY_MOBILE_SERVER: string = 'pendingMobileServer';

export async function setPendingMobileLogin(userId: string, loginToken: string,
  server: string): Promise<void> {
  try {
    const store: preferences.Preferences = await openStore();
    await store.put(KEY_MOBILE_USER, userId);
    await store.put(KEY_MOBILE_TOKEN, loginToken);
    await store.put(KEY_MOBILE_SERVER, server);
    await store.flush();
  } catch (error) {
    // 忽略
  }
}

export interface PendingMobileLogin {
  userId: string;
  loginToken: string;
  server: string;
}

export async function takePendingMobileLogin(): Promise<PendingMobileLogin | null> {
  try {
    const store: preferences.Preferences = await openStore();
    const userValue: preferences.ValueType = await store.get(KEY_MOBILE_USER, '');
    const tokenValue: preferences.ValueType = await store.get(KEY_MOBILE_TOKEN, '');
    const serverValue: preferences.ValueType = await store.get(KEY_MOBILE_SERVER, '');
    const userId: string = typeof userValue === 'string' ? userValue as string : '';
    const loginToken: string = typeof tokenValue === 'string' ? tokenValue as string : '';
    const server: string = typeof serverValue === 'string' ? serverValue as string : '';
    if (userId.length === 0 || loginToken.length === 0) {
      return null;
    }
    await store.delete(KEY_MOBILE_USER);
    await store.delete(KEY_MOBILE_TOKEN);
    await store.delete(KEY_MOBILE_SERVER);
    await store.flush();
    return { userId: userId, loginToken: loginToken, server: server };
  } catch (error) {
    return null;
  }
}
