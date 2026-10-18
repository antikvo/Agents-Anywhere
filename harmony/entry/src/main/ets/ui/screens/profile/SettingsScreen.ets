import { AuthApi } from '../../../api/AuthApi';
import { AuthMeResponse } from '../../../api/AuthDtos';
import { APP_VERSION } from '../../../core/AppConfig';
import { AuthController } from '../../../feature/auth/AuthController';
import { AuthSession } from '../../../feature/auth/AuthSessionStore';

/**
 * 设置页：账号、服务器、版本、外观说明与退出登录。
 * 头像上传、昵称修改、通知设置等后续补齐。
 */
@Component
export struct SettingsScreen {
  session: AuthSession | null = null;
  onBack: () => void = () => {
  };
  onSignOut: () => void = () => {
  };
  onOpenProjects: () => void = () => {
  };
  onProfileUpdated: (name: string) => void = () => {
  };
  private api: AuthApi = new AuthApi();
  private controller: AuthController = new AuthController();
  @State displayName: string = '';
  @State email: string = '';
  @State role: string = '';
  @State loading: boolean = true;
  @State errorMessage: string = '';
  @State message: string = '';
  @State nameOverlay: boolean = false;
  @State nameDraft: string = '';
  @State passwordOverlay: boolean = false;
  @State newPassword: string = '';
  @State confirmPassword: string = '';
  @State saving: boolean = false;

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    const session: AuthSession | null = this.session;
    if (session === null) {
      this.loading = false;
      return;
    }
    try {
      const me: AuthMeResponse = await this.api.me(session.serverUrl, session.accessToken);
      const name: string = me.displayName === null || me.displayName === undefined ? '' : me.displayName;
      this.displayName = name.length > 0 ? name : me.userId;
      this.email = me.email === null || me.email === undefined ? '' : me.email;
      this.role = me.role;
    } catch (error) {
      this.errorMessage = (error as Error).message;
    } finally {
      this.loading = false;
    }
  }

  @Builder
  infoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor('#8A8A8A')
        .width(88)
      Text(value)
        .fontSize(14)
        .fontColor('#111111')
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
  }

  private async saveDisplayName(): Promise<void> {
    const session: AuthSession | null = this.session;
    if (session === null || this.saving) {
      return;
    }
    if (this.nameDraft.trim().length === 0) {
      this.errorMessage = '昵称不能为空';
      return;
    }
    this.saving = true;
    this.errorMessage = '';
    this.message = '';
    try {
      const me: AuthMeResponse = await this.controller.updateDisplayName(session, this.nameDraft);
      const name: string = me.displayName === null || me.displayName === undefined ?
        this.nameDraft.trim() : me.displayName;
      this.displayName = name;
      this.onProfileUpdated(name);
      this.nameOverlay = false;
      this.message = '昵称已更新';
    } catch (error) {
      this.errorMessage = (error as Error).message;
    } finally {
      this.saving = false;
    }
  }

  private async savePassword(): Promise<void> {
    const session: AuthSession | null = this.session;
    if (session === null || this.saving) {
      return;
    }
    if (this.newPassword.length < 8) {
      this.errorMessage = '新密码至少 8 位';
      return;
    }
    if (this.newPassword !== this.confirmPassword) {
      this.errorMessage = '两次输入的密码不一致';
      return;
    }
    this.saving = true;
    this.errorMessage = '';
    try {
      await this.controller.changePassword(session, this.newPassword);
      this.passwordOverlay = false;
      this.newPassword = '';
      this.confirmPassword = '';
      this.message = '密码已更新';
    } catch (error) {
      this.errorMessage = (error as Error).message;
    } finally {
      this.saving = false;
    }
  }

  build() {
    Stack() {
    Column() {
      Row({ space: 8 }) {
        Button('返回')
          .height(32)
          .fontSize(13)
          .backgroundColor('#F2F2F2')
          .fontColor('#000000')
          .onClick(() => {
            this.onBack();
          })
        Text('设置')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#000000')
        Blank()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      if (this.loading) {
        Column() {
          LoadingProgress().width(40).height(40)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            if (this.message.length > 0) {
              Text(this.message)
                .fontSize(12)
                .fontColor('#1F7A1F')
                .width('100%')
                .padding({ top: 8, bottom: 4 })
            }

            if (this.errorMessage.length > 0) {
              Text(this.errorMessage)
                .fontSize(13)
                .fontColor('#D93026')
                .width('100%')
                .padding({ top: 8, bottom: 8 })
            }

            Text('账号')
              .fontSize(12)
              .fontColor('#8A8A8A')
              .width('100%')
              .padding({ top: 8 })
            Row() {
              Text('昵称')
                .fontSize(13)
                .fontColor('#8A8A8A')
                .width(88)
              Text(this.displayName)
                .fontSize(14)
                .fontColor('#111111')
                .layoutWeight(1)
              Text('修改 ›')
                .fontSize(13)
                .fontColor('#8A8A8A')
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })
            .onClick(() => {
              this.nameDraft = this.displayName;
              this.nameOverlay = true;
            })
            Divider().color('#EFEFEF')
            this.infoRow('邮箱', this.email.length > 0 ? this.email : '未绑定')
            Divider().color('#EFEFEF')
            this.infoRow('角色', this.role)
            Divider().color('#EFEFEF')
            Row() {
              Text('修改密码')
                .fontSize(14)
                .fontColor('#111111')
                .layoutWeight(1)
              Text('›')
                .fontSize(14)
                .fontColor('#8A8A8A')
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })
            .onClick(() => {
              this.newPassword = '';
              this.confirmPassword = '';
              this.passwordOverlay = true;
            })

            Text('服务')
              .fontSize(12)
              .fontColor('#8A8A8A')
              .width('100%')
              .padding({ top: 20 })
            this.infoRow('服务器', this.session !== null ? this.session.serverUrl : '—')
            Divider().color('#EFEFEF')
            this.infoRow('版本', APP_VERSION)

            Text('工作区')
              .fontSize(12)
              .fontColor('#8A8A8A')
              .width('100%')
              .padding({ top: 20 })
            Row() {
              Text('项目')
                .fontSize(14)
                .fontColor('#111111')
                .layoutWeight(1)
              Text('管理 ›')
                .fontSize(13)
                .fontColor('#8A8A8A')
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })
            .onClick(() => {
              this.onOpenProjects();
            })
            Divider().color('#EFEFEF')

            Text('关于')
              .fontSize(12)
              .fontColor('#8A8A8A')
              .width('100%')
              .padding({ top: 20 })
            this.infoRow('客户端', 'Agents Anywhere HarmonyOS')
            this.infoRow('外观', '跟随系统')
            Text('隐私说明：会话内容、时间线与附件可能经过你连接的服务端；自托管时数据由你自己的实例处理。')
              .fontSize(12)
              .fontColor('#8A8A8A')
              .width('100%')
              .padding({ top: 8, bottom: 16 })

            Button('退出登录')
              .width('100%')
              .height(44)
              .backgroundColor('#FDF1F0')
              .fontColor('#D93026')
              .onClick(() => {
                this.onSignOut();
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 24 })
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')

      if (this.nameOverlay) {
        Column({ space: 10 }) {
          Text('修改昵称')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#000000')
            .width('100%')
          TextInput({ placeholder: '昵称', text: this.nameDraft })
            .height(40)
            .fontSize(14)
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
            .onChange((value: string) => {
              this.nameDraft = value;
            })
          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .fontSize(12)
              .fontColor('#D93026')
              .width('100%')
          }
          Row({ space: 8 }) {
            Button(this.saving ? '保存中…' : '保存')
              .height(34)
              .enabled(!this.saving)
              .onClick(() => {
                this.saveDisplayName();
              })
            Button('取消')
              .height(34)
              .backgroundColor('#F2F2F2')
              .fontColor('#111111')
              .onClick(() => {
                this.nameOverlay = false;
                this.errorMessage = '';
              })
          }
          .width('100%')
        }
        .width('86%')
        .padding(16)
        .borderRadius(12)
        .backgroundColor('#FFFFFF')
      }

      if (this.passwordOverlay) {
        Column({ space: 10 }) {
          Text('修改密码')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#000000')
            .width('100%')
          TextInput({ placeholder: '新密码（至少 8 位）', text: this.newPassword })
            .height(40)
            .fontSize(14)
            .type(InputType.Password)
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
            .onChange((value: string) => {
              this.newPassword = value;
            })
          TextInput({ placeholder: '再次输入新密码', text: this.confirmPassword })
            .height(40)
            .fontSize(14)
            .type(InputType.Password)
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
            .onChange((value: string) => {
              this.confirmPassword = value;
            })
          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .fontSize(12)
              .fontColor('#D93026')
              .width('100%')
          }
          Row({ space: 8 }) {
            Button(this.saving ? '保存中…' : '保存')
              .height(34)
              .enabled(!this.saving)
              .onClick(() => {
                this.savePassword();
              })
            Button('取消')
              .height(34)
              .backgroundColor('#F2F2F2')
              .fontColor('#111111')
              .onClick(() => {
                this.passwordOverlay = false;
                this.errorMessage = '';
              })
          }
          .width('100%')
        }
        .width('86%')
        .padding(16)
        .borderRadius(12)
        .backgroundColor('#FFFFFF')
      }
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
  }
}
