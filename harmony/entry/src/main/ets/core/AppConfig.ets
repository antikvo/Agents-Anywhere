import { normalizeServerOrigin } from './ServerUrl';

/**
 * 应用级常量。
 *
 * 与 Android 的 app/config/AppConfig.kt 对应：官方服务地址可在构建时替换，
 * 自托管用户在登录页填写自己的地址。
 */
export const OFFICIAL_SERVER_URL: string = 'https://web.agents-anywhere.com';
export const API_NAMESPACE: string = '/api/v2';
export const APP_VERSION: string = '2.1.0';

export const AUTH_PREFERENCES_NAME: string = 'agents_anywhere_auth';

export function isOfficialServer(serverUrl: string): boolean {
  const official: string | null = normalizeServerOrigin(OFFICIAL_SERVER_URL);
  const candidate: string | null = normalizeServerOrigin(serverUrl);
  return official !== null && candidate !== null && official === candidate;
}
