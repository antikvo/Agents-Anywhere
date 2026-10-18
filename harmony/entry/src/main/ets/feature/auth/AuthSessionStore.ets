import { AuthResponse } from '../../api/AuthDtos';
import { AUTH_PREFERENCES_NAME } from '../../core/AppConfig';
import { AppContextHolder } from '../../core/AppContextHolder';
import { normalizeServerOrigin } from '../../core/ServerUrl';
import { PreferencesStore } from '../../platform/PreferencesStore';
import { SecureTokenStore } from '../../platform/SecureTokenStore';

const KEY_SERVER_URL = 'server_url';
const KEY_ACCESS_TOKEN = 'access_token';
const KEY_TOKEN_TYPE = 'token_type';
const KEY_USER_ID = 'user_id';
const KEY_ROLE = 'role';
const KEY_DISPLAY_NAME = 'display_name';
const KEY_EMAIL = 'email';

export interface AuthSession {
  serverUrl: string;
  accessToken: string;
  tokenType: string;
  userId: string;
  role: string;
  displayName?: string | null;
  email?: string | null;
}

/**
 * 登录态存储，行为对齐 Android 的 AuthSessionStore：
 * 退出登录时保留服务器地址，方便再次登录。
 */
export class AuthSessionStore {
  private readonly store: PreferencesStore;
  private readonly secure: SecureTokenStore = new SecureTokenStore();

  constructor() {
    this.store = new PreferencesStore(AppContextHolder.require(), AUTH_PREFERENCES_NAME);
  }

  async readServerUrl(): Promise<string> {
    const stored: string = await this.store.getString(KEY_SERVER_URL);
    const normalized: string | null = normalizeServerOrigin(stored);
    return normalized === null ? '' : normalized;
  }

  async read(): Promise<AuthSession | null> {
    const serverUrl: string = await this.readServerUrl();
    let accessToken: string = await this.secure.load(serverUrl);
    if (accessToken.length === 0) {
      accessToken = await this.store.getString(KEY_ACCESS_TOKEN);
    }
    if (serverUrl.length === 0 || accessToken.length === 0) {
      return null;
    }
    const session: AuthSession = {
      serverUrl: serverUrl,
      accessToken: accessToken,
      tokenType: await this.store.getString(KEY_TOKEN_TYPE, 'Bearer'),
      userId: await this.store.getString(KEY_USER_ID),
      role: await this.store.getString(KEY_ROLE),
      displayName: await this.store.getString(KEY_DISPLAY_NAME),
      email: await this.store.getString(KEY_EMAIL)
    };
    return session;
  }

  async save(serverUrl: string, auth: AuthResponse): Promise<AuthSession> {
    const origin: string | null = normalizeServerOrigin(serverUrl);
    if (origin === null) {
      throw new Error('Server URL must be an HTTP(S) origin.');
    }
    await this.store.putString(KEY_SERVER_URL, origin);
    const secured: boolean = await this.secure.save(origin, auth.accessToken);
    if (!secured) {
      await this.store.putString(KEY_ACCESS_TOKEN, auth.accessToken);
    } else {
      await this.store.putString(KEY_ACCESS_TOKEN, '');
    }
    await this.store.putString(KEY_TOKEN_TYPE, auth.tokenType);
    await this.store.putString(KEY_USER_ID, auth.userId);
    await this.store.putString(KEY_ROLE, auth.role);
    const displayName: string = auth.displayName === null || auth.displayName === undefined ?
      '' : auth.displayName;
    const email: string = auth.email === null || auth.email === undefined ? '' : auth.email;
    await this.store.putString(KEY_DISPLAY_NAME, displayName);
    await this.store.putString(KEY_EMAIL, email);
    const session: AuthSession = {
      serverUrl: origin,
      accessToken: auth.accessToken,
      tokenType: auth.tokenType,
      userId: auth.userId,
      role: auth.role,
      displayName: displayName,
      email: email
    };
    return session;
  }

  async updateDisplayName(displayName: string): Promise<void> {
    await this.store.putString(KEY_DISPLAY_NAME, displayName);
  }

  async clear(): Promise<void> {
    const serverUrl: string = await this.readServerUrl();
    if (serverUrl.length > 0) {
      await this.secure.clear(serverUrl);
    }
    await this.store.remove(KEY_ACCESS_TOKEN);
    await this.store.remove(KEY_TOKEN_TYPE);
    await this.store.remove(KEY_USER_ID);
    await this.store.remove(KEY_ROLE);
    await this.store.remove(KEY_DISPLAY_NAME);
    await this.store.remove(KEY_EMAIL);
    if (serverUrl.length > 0) {
      await this.store.putString(KEY_SERVER_URL, serverUrl);
    }
  }
}
