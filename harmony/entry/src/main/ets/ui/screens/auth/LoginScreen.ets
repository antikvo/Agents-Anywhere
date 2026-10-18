import { OFFICIAL_SERVER_URL } from '../../../core/AppConfig';
import { AuthController } from '../../../feature/auth/AuthController';
import { AuthSession } from '../../../feature/auth/AuthSessionStore';

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

  aboutToAppear(): void {
    this.prefillServer();
  }

  private async prefillServer(): Promise<void> {
    const saved: string = await this.controller.savedServerUrl();
    if (saved.length > 0) {
      this.serverUrl = saved;
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

        Button(this.busy ? '登录中…' : '登录')
          .width('100%')
          .height(48)
          .enabled(!this.busy)
          .onClick(() => {
            this.submit();
          })

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
