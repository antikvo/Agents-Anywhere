import { AuthApi } from '../../api/AuthApi';
import { AuthMeResponse } from '../../api/AuthDtos';
import { normalizeServerOrigin } from '../../core/ServerUrl';
import { AuthSession, AuthSessionStore } from './AuthSessionStore';

/**
 * 登录流程：校验地址 → 健康检查 → 登录 → 保存会话。
 * 与 Android AuthController / iOS V2AccountService 的职责一致。
 */
export class AuthController {
  private readonly api: AuthApi;
  private readonly store: AuthSessionStore;

  constructor(api: AuthApi = new AuthApi(), store: AuthSessionStore = new AuthSessionStore()) {
    this.api = api;
    this.store = store;
  }

  normalizeServerUrl(serverUrl: string): string | null {
    return normalizeServerOrigin(serverUrl);
  }

  async restore(): Promise<AuthSession | null> {
    return await this.store.read();
  }

  async updateDisplayName(session: AuthSession, displayName: string): Promise<AuthMeResponse> {
    const me: AuthMeResponse = await this.api.updateProfile(session.serverUrl, session.accessToken,
      displayName.trim());
    const name: string = me.displayName === null || me.displayName === undefined ? displayName : me.displayName;
    await this.store.updateDisplayName(name);
    return me;
  }

  async persistDisplayName(displayName: string): Promise<void> {
    await this.store.updateDisplayName(displayName);
  }

  async changePassword(session: AuthSession, newPassword: string): Promise<void> {
    await this.api.changePassword(session.serverUrl, session.accessToken, newPassword);
  }

  async savedServerUrl(): Promise<string> {
    return await this.store.readServerUrl();
  }

  async signIn(serverUrl: string, email: string, password: string): Promise<AuthSession> {
    const origin: string | null = normalizeServerOrigin(serverUrl);
    if (origin === null) {
      throw new Error('请输入有效的服务器地址，例如 https://aa.example.com');
    }
    if (email.trim().length === 0 || password.length === 0) {
      throw new Error('请输入邮箱和密码');
    }
    await this.api.health(origin);
    const auth = await this.api.login(origin, email, password);
    return await this.store.save(origin, auth);
  }

  async signOut(): Promise<void> {
    await this.store.clear();
  }

  async me(session: AuthSession): Promise<AuthMeResponse> {
    return await this.api.me(session.serverUrl, session.accessToken);
  }

  async authConfig(serverUrl: string): Promise<boolean> {
    const origin: string | null = normalizeServerOrigin(serverUrl);
    if (origin === null) {
      throw new Error('请输入有效的服务器地址');
    }
    const config = await this.api.authConfig(origin);
    return config.needsBootstrap;
  }
}
