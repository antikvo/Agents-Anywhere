/**
 * 与 /api/v2 认证端点对应的 DTO。
 * 字段来自 server/agent_server/api/auth.py 与 Android api/AuthDtos.kt。
 */

export interface AuthResponse {
  userId: string;
  role: string;
  accessToken: string;
  tokenType: string;
  serverTime: string;
  email?: string;
  displayName?: string;
  emailVerified?: boolean;
}

export interface RegisterPayload {
  email: string;
  password: string;
  displayName?: string;
  setupToken?: string;
}

export interface AuthMeResponse {
  userId: string;
  role: string;
  disabled: boolean;
  avatar?: string;
  serverTime: string;
  email?: string;
  displayName?: string;
  emailVerified?: boolean;
}

export interface AuthConfigResponse {
  needsBootstrap: boolean;
  registrationOpen: boolean;
  oauthRegistrationOpen: boolean;
  oauthEnabled: boolean;
  oauthProviderLabel?: string;
  setupTokenExpiresAt?: string;
  serverTime: string;
  emailVerificationRequired?: boolean;
  passwordResetEnabled?: boolean;
}

export interface HealthResponse {
  status: string;
  version?: string;
}
