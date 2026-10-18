import { OFFICIAL_SERVER_URL } from '../../../core/AppConfig';
import { AuthController } from '../../../feature/auth/AuthController';
import { AuthSession } from '../../../feature/auth/AuthSessionStore';
import { PendingMobileLogin, takePendingMobileLogin } from '../../../platform/DeepLinkPrefs';

/**
 * 登录页：服务器地址 + 邮箱 + 密码。
 *
 * 支持 Cloud 与自托管：地址留空时使用官方服务，自托管用户填写自己的地址。
 * 扫码登录、注册、OAuth 在 M0 后续任务中补齐。
 */
@Component
export struct LoginScreen {
  controller: AuthController = new AuthController();
  onSignedIn: (session: AuthSession) => void = () => {
  };
  @State serverUrl: string = OFFICIAL_SERVER_URL;
  @State email: string = '';
  @State password: string = '';
  @State busy: boolean = false;
  @State errorMessage: string = '';
  @State qrMode: boolean = false;
  @State qrPayload: string = '';
  @State qrUserId: string = '';
  @State qrToken: string = '';
  @State qrStatus: string = '';

  aboutToAppear(): void {
    this.prefillServer();
  }

  private async prefillServer(): Promise<void> {
    const saved: string = await this.controller.savedServerUrl();
    if (saved.length > 0) {
      this.serverUrl = saved;
    }
    let pending: PendingMobileLogin | null = await takePendingMobileLogin();
    for (let attempt = 0; attempt < 6 && pending === null; attempt++) {
      await new Promise<void>((resolve: () => void) => {
        setTimeout(() => {
          resolve();
        }, 200);
      });
      pending = await takePendingMobileLogin();
    }
    if (pending !== null) {
      this.qrMode = true;
      this.qrUserId = pending.userId;
      this.qrToken = pending.loginToken;
      if (pending.server.length > 0) {
        this.serverUrl = pending.server;
      }
      this.qrStatus = '已从扫码深链填入，等待桌面端确认';
    }
  }

  private async submit(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.errorMessage = '';
    try {
      const session: AuthSession = await this.controller.signIn(this.serverUrl, this.email, this.password);
      this.onSignedIn(session);
    } catch (error) {
      this.errorMessage = (error as Error).message;
    } finally {
      this.busy = false;
    }
  }

  private parseQrPayload(raw: string): Record<string, string> | null {
    try {
      const parsed = JSON.parse(raw.trim()) as Record<string, string>;
      return parsed;
    } catch (error) {
      return null;
    }
  }

  private async submitQr(): Promise<void> {
    if (this.busy) {
      return;
    }
    const userId: string = this.qrUserId.trim();
    const loginToken: string = this.qrToken.trim();
    if (userId.length === 0 || loginToken.length === 0) {
      this.errorMessage = '请填写用户 ID 与登录令牌';
      return;
    }
    const targetServer: string = this.serverUrl;
    this.busy = true;
    this.errorMessage = '';
    this.qrStatus = '等待桌面端确认…';
    try {
      const session: AuthSession = await this.controller.signInWithMobileLogin(targetServer,
        userId, loginToken);
      this.onSignedIn(session);
    } catch (error) {
      this.errorMessage = (error as Error).message;
      this.qrStatus = '';
    } finally {
      this.busy = false;
    }
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Text('Agents Anywhere')
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .fontColor('#000000')
        Text('登录到你的服务')
          .fontSize(14)
          .fontColor('#666666')
          .margin({ bottom: 12 })

        TextInput({ placeholder: '服务器地址', text: this.serverUrl })
          .type(InputType.URL)
          .height(48)
          .width('100%')
          .onChange((value: string) => {
            this.serverUrl = value;
          })

        TextInput({ placeholder: '邮箱', text: this.email })
          .type(InputType.Email)
          .height(48)
          .width('100%')
          .onChange((value: string) => {
            this.email = value;
          })

        if (this.qrMode) {
          TextInput({ placeholder: '用户 ID（二维码中的 userId）', text: this.qrUserId })
            .height(44)
            .width('100%')
            .fontSize(12)
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
            .onChange((value: string) => {
              this.qrUserId = value;
            })
          TextArea({ placeholder: '登录令牌（二维码中的 loginToken）', text: this.qrToken })
            .height(96)
            .width('100%')
            .fontSize(11)
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
            .onChange((value: string) => {
              this.qrToken = value;
            })
          if (this.qrStatus.length > 0) {
            Text(this.qrStatus)
              .fontSize(12)
              .fontColor('#8A8A8A')
              .width('100%')
          }
        }

        TextInput({ placeholder: '密码', text: this.password })
          .type(InputType.Password)
          .height(48)
          .width('100%')
          .onChange((value: string) => {
            this.password = value;
          })

        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(13)
            .fontColor('#D93026')
            .width('100%')
        }

        if (this.qrMode) {
          Button(this.busy ? '等待确认…' : '扫码登录')
            .width('100%')
            .height(48)
            .enabled(!this.busy && this.qrUserId.trim().length > 0 &&
              this.qrToken.trim().length > 0)
            .onClick(() => {
              this.submitQr();
            })
        }

        Button(this.busy ? '登录中…' : (this.qrMode ? '使用密码登录' : '登录'))
          .width('100%')
          .height(48)
          .backgroundColor(this.qrMode ? '#F2F2F2' : '#000000')
          .fontColor(this.qrMode ? '#111111' : '#FFFFFF')
          .enabled(!this.busy)
          .onClick(() => {
            if (this.qrMode) {
              this.qrMode = false;
              this.errorMessage = '';
              this.qrStatus = '';
              return;
            }
            this.submit();
          })

        if (!this.qrMode) {
          Button('扫码登录（粘贴二维码内容）')
            .width('100%')
            .height(40)
            .backgroundColor('#F2F2F2')
            .fontColor('#000000')
            .onClick(() => {
              this.qrMode = true;
              this.errorMessage = '';
            })
        }

        Button('使用官方服务')
          .width('100%')
          .height(40)
          .backgroundColor('#F2F2F2')
          .fontColor('#000000')
          .onClick(() => {
            this.serverUrl = OFFICIAL_SERVER_URL;
          })
      }
      .width('100%')
      .padding(24)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Center)
  }
}
