import { http } from '@kit.NetworkKit';
import { HTTP_METHOD_POST } from './HttpClient';
import { apiUrl } from '../core/ServerUrl';
import { ApiError, ApiErrorKind, HttpClient } from './HttpClient';
import { AuthConfigResponse, AuthMeResponse, AuthResponse, HealthResponse } from './AuthDtos';

interface LoginPayload {
  email: string;
  password: string;
}

interface UpdateProfilePayload {
  displayName: string;
}

interface ChangePasswordPayload {
  newPassword: string;
}

interface MobileLoginRequestPayload {
  userId: string;
  loginToken: string;
  deviceName: string;
}

interface MobileLoginStatusPayload {
  loginToken: string;
}

interface MobileLoginExchangePayload {
  userId: string;
  loginToken: string;
}

export interface MobileLoginStatusResponse {
  status: string;
  userId?: string | null;
  deviceName?: string | null;
  expiresAt?: string | null;
}

interface MobileLoginExchangeResponse {
  auth: AuthResponse;
  refreshToken: string;
  expiresAt: string;
  serverTime: string;
}

export class AuthApi {
  private readonly client: HttpClient;

  constructor(client: HttpClient = new HttpClient()) {
    this.client = client;
  }

  async health(serverUrl: string): Promise<HealthResponse> {
    const text: string = await this.client.requestJson(apiUrl(serverUrl, '/health'));
    const health: HealthResponse = JSON.parse(text) as HealthResponse;
    if (health.status !== 'ok') {
      throw new ApiError(ApiErrorKind.Server, '该地址没有返回可用的 Agents Anywhere 服务。');
    }
    return health;
  }

  async authConfig(serverUrl: string): Promise<AuthConfigResponse> {
    const text: string = await this.client.requestJson(apiUrl(serverUrl, '/auth/config'));
    return JSON.parse(text) as AuthConfigResponse;
  }

  async login(serverUrl: string, email: string, password: string): Promise<AuthResponse> {
    const payload: LoginPayload = { email: email.trim(), password: password };
    const text: string = await this.client.requestJson(apiUrl(serverUrl, '/auth/login'), {
      method: http.RequestMethod.POST,
      body: JSON.stringify(payload)
    });
    return JSON.parse(text) as AuthResponse;
  }

  async updateProfile(serverUrl: string, token: string, displayName: string): Promise<AuthMeResponse> {
    const payload: UpdateProfilePayload = { displayName: displayName };
    const text: string = await this.client.requestJson(apiUrl(serverUrl, '/auth/me/profile'), {
      method: http.RequestMethod.PUT,
      token: token,
      body: JSON.stringify(payload)
    });
    return JSON.parse(text) as AuthMeResponse;
  }

  async changePassword(serverUrl: string, token: string, newPassword: string): Promise<void> {
    const payload: ChangePasswordPayload = { newPassword: newPassword };
    await this.client.requestJson(apiUrl(serverUrl, '/auth/change-password'), {
      method: http.RequestMethod.POST,
      token: token,
      body: JSON.stringify(payload)
    });
  }

  async requestMobileLogin(serverUrl: string, userId: string, loginToken: string,
    deviceName: string): Promise<MobileLoginStatusResponse> {
    const payload: MobileLoginRequestPayload = {
      userId: userId,
      loginToken: loginToken,
      deviceName: deviceName
    };
    const text: string = await this.client.requestJson(
      apiUrl(serverUrl, '/auth/mobile-login/request'), {
        method: HTTP_METHOD_POST,
        body: JSON.stringify(payload)
      });
    return JSON.parse(text) as MobileLoginStatusResponse;
  }

  async mobileLoginStatus(serverUrl: string, loginToken: string): Promise<MobileLoginStatusResponse> {
    const payload: MobileLoginStatusPayload = { loginToken: loginToken };
    const text: string = await this.client.requestJson(
      apiUrl(serverUrl, '/auth/mobile-login/status'), {
        method: HTTP_METHOD_POST,
        body: JSON.stringify(payload)
      });
    return JSON.parse(text) as MobileLoginStatusResponse;
  }

  async exchangeMobileLogin(serverUrl: string, userId: string,
    loginToken: string): Promise<AuthResponse> {
    const payload: MobileLoginExchangePayload = { userId: userId, loginToken: loginToken };
    const text: string = await this.client.requestJson(
      apiUrl(serverUrl, '/auth/mobile-login/exchange'), {
        method: HTTP_METHOD_POST,
        body: JSON.stringify(payload)
      });
    const response: MobileLoginExchangeResponse = JSON.parse(text) as MobileLoginExchangeResponse;
    return response.auth;
  }

  async me(serverUrl: string, token: string): Promise<AuthMeResponse> {
    const text: string = await this.client.requestJson(apiUrl(serverUrl, '/auth/me'), { token: token });
    return JSON.parse(text) as AuthMeResponse;
  }
}
