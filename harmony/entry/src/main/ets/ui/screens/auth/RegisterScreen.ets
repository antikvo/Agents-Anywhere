import { AuthController } from '../../../feature/auth/AuthController';
import { AuthSession } from '../../../feature/auth/AuthSessionStore';

/**
 * 注册 / 首位管理员初始化。
 * 服务端 `/auth/config` 决定入口是否展示：registrationOpen（普通注册）或 needsBootstrap（setup token）。
 */
@Component
export struct RegisterScreen {
  controller: AuthController = new AuthController();
  serverUrl: string = '';
  needsBootstrap: boolean = false;
  onRegistered: (session: AuthSession) => void = () => {
  };
  onBack: () => void = () => {
  };
  @State email: string = '';
  @State password: string = '';
  @State confirmPassword: string = '';
  @State setupToken: string = '';
  @State busy: boolean = false;
  @State errorMessage: string = '';

  private async submit(): Promise<void> {
    if (this.busy) {
      return;
    }
    if (this.password !== this.confirmPassword) {
      this.errorMessage = '两次输入的密码不一致';
      return;
    }
    this.busy = true;
    this.errorMessage = '';
    try {
      const session: AuthSession = await this.controller.register(this.serverUrl, this.email,
        this.password, this.setupToken);
      this.onRegistered(session);
    } catch (error) {
      this.errorMessage = (error as Error).message;
    } finally {
      this.busy = false;
    }
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Button('返回')
          .height(32)
          .fontSize(13)
          .backgroundColor('#F2F2F2')
          .fontColor('#000000')
          .onClick(() => {
            this.onBack();
          })
        Blank()
      }
      .width('100%')

      Text(this.needsBootstrap ? '创建首位管理员' : '注册账号')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor('#000000')
        .width('100%')
      Text(this.serverUrl)
        .fontSize(12)
        .fontColor('#8A8A8A')
        .width('100%')

      TextInput({ placeholder: '邮箱', text: this.email })
        .height(46)
        .type(InputType.Email)
        .onChange((value: string) => {
          this.email = value;
        })
      TextInput({ placeholder: '密码', text: this.password })
        .height(46)
        .type(InputType.Password)
        .onChange((value: string) => {
          this.password = value;
        })
      TextInput({ placeholder: '确认密码', text: this.confirmPassword })
        .height(46)
        .type(InputType.Password)
        .onChange((value: string) => {
          this.confirmPassword = value;
        })
      if (this.needsBootstrap) {
        TextInput({ placeholder: '初始化令牌（见服务端日志）', text: this.setupToken })
          .height(46)
          .onChange((value: string) => {
            this.setupToken = value;
          })
      }

      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .fontSize(12)
          .fontColor('#D93026')
          .width('100%')
      }

      Button(this.busy ? '注册中…' : (this.needsBootstrap ? '创建管理员' : '注册'))
        .width('100%')
        .height(46)
        .enabled(!this.busy)
        .backgroundColor('#111111')
        .fontColor('#FFFFFF')
        .onClick(() => {
          this.submit();
        })
      Blank()
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .backgroundColor('#FFFFFF')
  }
}
