import { http } from '@kit.NetworkKit';
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

  async me(serverUrl: string, token: string): Promise<AuthMeResponse> {
    const text: string = await this.client.requestJson(apiUrl(serverUrl, '/auth/me'), { token: token });
    return JSON.parse(text) as AuthMeResponse;
  }
}
