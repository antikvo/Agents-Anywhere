import { AuthSession } from '../../../feature/auth/AuthSessionStore';
import {
  RealtimeState,
  SessionDetailController,
  SessionDetailResult
} from '../../../feature/sessiondetail/SessionDetailController';
import { NoticeActionDto, NoticeDto, RuntimeStateDto } from '../../../api/ProtocolDtos';
import { SessionView } from '../../../api/SessionDtos';
import { SessionItem, statusColor, statusLabel, toStatusKind } from '../../../model/Session';
import { TimelineRow, TimelineRowKind } from '../../../model/Timeline';
import { MarkdownView } from '../../components/MarkdownView';
import { AttachmentImage } from '../../components/AttachmentImage';
import { AttachmentRefDto } from '../../../api/ProtocolDtos';
import { UploadedAttachment } from '../../../api/AttachmentsApi';
import { InputAnswersPayload, InputRequestForm, parseInputRequest } from '../../../model/InputRequest';
import { InputRequestCard } from '../../components/InputRequestCard';
import { TerminalScreen } from '../terminal/TerminalScreen';
import { parseQuestionReply, QuestionAnswer } from '../../../model/ProtocolMessages';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit';

/**
 * 会话详情：快照 + WS 实时 + 审批/输入请求卡片 + 发送消息。
 */
@Component
export struct SessionDetailScreen {
  session: AuthSession | null = null;
  initial: SessionItem | null = null;
  onBack: () => void = () => {
  };
  private controller: SessionDetailController = new SessionDetailController();
  @State title: string = '';
  @State statusText: string = '';
  @State statusTint: string = '#8A8A8A';
  @State rows: TimelineRow[] = [];
  @State notices: NoticeDto[] = [];
  @State loading: boolean = true;
  @State errorMessage: string = '';
  @State liveText: string = '连接中';
  @State liveConnected: boolean = false;
  @State draft: string = '';
  @State actionBusy: boolean = false;
  @State actionError: string = '';
  @State takeover: boolean = false;
  @State hasMore: boolean = false;
  @State loadingOlder: boolean = false;
  @State showSettings: boolean = false;
  @State runtimeSummary: string = '';
  @State selectionLines: string[] = [];
  @State pendingNames: string[] = [];
  @State uploading: boolean = false;
  @State showTerminal: boolean = false;

  aboutToAppear(): void {
    if (this.initial !== null) {
      this.title = this.initial.title;
      this.statusText = this.initial.statusLabel;
      this.statusTint = statusColor(this.initial.statusKind);
    }
    this.controller.onRows = (rows: TimelineRow[]) => {
      this.rows = rows;
    };
    this.controller.onState = (state: RealtimeState, detail: string) => {
      this.liveText = detail;
      this.liveConnected = state === RealtimeState.Connected;
    };
    this.controller.onSessionMeta = (session: SessionView) => {
      this.applySession(session);
    };
    this.controller.onNotices = (notices: NoticeDto[]) => {
      this.notices = notices;
    };
    this.load();
  }

  aboutToDisappear(): void {
    this.controller.disconnect();
  }

  private applySession(session: SessionView): void {
    const nextTitle: string = session.title === null || session.title === undefined ? '' : session.title;
    if (nextTitle.length > 0) {
      this.title = nextTitle;
    }
    const nextStatus = toStatusKind(session.status);
    this.statusText = statusLabel(nextStatus);
    this.statusTint = statusColor(nextStatus);
    this.takeover = session.takeover;
  }

  private async load(): Promise<void> {
    const session: AuthSession | null = this.session;
    const initial: SessionItem | null = this.initial;
    if (session === null || initial === null) {
      return;
    }
    this.loading = true;
    this.errorMessage = '';
    try {
      const result: SessionDetailResult = await this.controller.load(session, initial.id);
      const nextTitle: string = result.session.title === null || result.session.title === undefined ?
        '' : result.session.title;
      this.title = nextTitle.length > 0 ? nextTitle : initial.title;
      this.statusText = statusLabel(toStatusKind(result.session.status));
      this.statusTint = statusColor(toStatusKind(result.session.status));
      this.rows = result.rows;
      this.notices = result.notices;
      this.takeover = result.session.takeover;
      this.hasMore = result.hasMore;
      this.controller.connect();
    } catch (error) {
      this.errorMessage = (error as Error).message;
    } finally {
      this.loading = false;
    }
  }

  private async send(): Promise<void> {
    const content: string = this.draft.trim();
    if ((content.length === 0 && this.pendingNames.length === 0) || this.actionBusy) {
      return;
    }
    this.actionBusy = true;
    this.actionError = '';
    try {
      await this.controller.sendMessage(content);
      this.draft = '';
      this.pendingNames = [];
    } catch (error) {
      this.actionError = (error as Error).message;
    } finally {
      this.actionBusy = false;
    }
  }

  private async pickAttachment(): Promise<void> {
    if (this.uploading) {
      return;
    }
    this.actionError = '';
    try {
      const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      });
      if (result.photoUris.length === 0) {
        return;
      }
      const uri: string = result.photoUris[0];
      const name: string = uri.substring(uri.lastIndexOf('/') + 1);
      const lower: string = name.toLowerCase();
      const mediaType: string = lower.endsWith('.png') ? 'image/png' : 'image/jpeg';
      this.uploading = true;
      const data: ArrayBuffer = this.readFileBytes(uri);
      const uploaded: UploadedAttachment = await this.controller.uploadAttachment(name, mediaType, data);
      this.pendingNames.push(uploaded.name);
    } catch (error) {
      this.actionError = (error as Error).message;
    } finally {
      this.uploading = false;
    }
  }

  private readFileBytes(uri: string): ArrayBuffer {
    const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
    try {
      const stat = fileIo.statSync(file.fd);
      const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buffer);
      return buffer;
    } finally {
      fileIo.closeSync(file);
    }
  }

  private async openSettings(): Promise<void> {
    this.showSettings = true;
    const state: RuntimeStateDto | null = await this.controller.refreshRuntimeState();
    if (state === null) {
      this.runtimeSummary = '暂无法获取运行状态';
      this.selectionLines = [];
      return;
    }
    this.runtimeSummary = `运行时 ${state.runtime} · 状态 ${state.status} · seq ${state.updatedSeq}`;
    const lines: string[] = [];
    const selections: Record<string, string> | null = state.selections;
    if (selections !== null) {
      Object.keys(selections).forEach((key: string) => {
        lines.push(`${key}: ${selections[key]}`);
      });
    }
    this.selectionLines = lines;
  }

  private async loadOlder(): Promise<void> {
    if (!this.hasMore || this.loadingOlder) {
      return;
    }
    this.loadingOlder = true;
    try {
      await this.controller.loadOlder();
      this.hasMore = this.controller.hasMoreItems();
    } catch (error) {
      this.actionError = (error as Error).message;
    } finally {
      this.loadingOlder = false;
    }
  }

  private async toggleTakeover(): Promise<void> {
    if (this.actionBusy) {
      return;
    }
    this.actionBusy = true;
    this.actionError = '';
    try {
      const session: SessionView = await this.controller.setTakeover(!this.takeover);
      this.takeover = session.takeover;
    } catch (error) {
      this.actionError = (error as Error).message;
    } finally {
      this.actionBusy = false;
    }
  }

  private async interruptRun(): Promise<void> {
    if (this.actionBusy) {
      return;
    }
    this.actionBusy = true;
    this.actionError = '';
    try {
      await this.controller.interrupt();
    } catch (error) {
      this.actionError = (error as Error).message;
    } finally {
      this.actionBusy = false;
    }
  }

  /**
   * 部分 runtime 的 notice.message 是 JSON 字符串（例如 {"detail": "..."}），
   * 直接展示可读性差；这里尽量提取人类可读的部分。
   */
  private noticeMessage(notice: NoticeDto): string {
    const raw: string | null | undefined = notice.message;
    if (raw === null || raw === undefined || raw.length === 0) {
      return '';
    }
    const text: string = raw.trim();
    if (!text.startsWith('{')) {
      return text;
    }
    interface NoticeErrorPayload {
      detail?: string;
      message?: string;
      error?: string;
    }
    try {
      const parsed: NoticeErrorPayload = JSON.parse(text) as NoticeErrorPayload;
      if (parsed.detail !== undefined && parsed.detail.length > 0) {
        return parsed.detail;
      }
      if (parsed.message !== undefined && parsed.message.length > 0) {
        return parsed.message;
      }
      if (parsed.error !== undefined && parsed.error.length > 0) {
        return parsed.error;
      }
    } catch (error) {
      // 不是合法 JSON，按原文展示
    }
    return text;
  }

  private inputForm(notice: NoticeDto): InputRequestForm | null {
    return parseInputRequest(notice.actions);
  }

  private async respond(notice: NoticeDto, actionId: string, input?: Object): Promise<void> {
    if (this.actionBusy) {
      return;
    }
    this.actionBusy = true;
    this.actionError = '';
    try {
      await this.controller.respondNotice(notice.noticeId, actionId, input);
    } catch (error) {
      this.actionError = (error as Error).message;
    } finally {
      this.actionBusy = false;
    }
  }

  @Builder
  noticeCard(notice: NoticeDto) {
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        Circle()
          .width(7)
          .height(7)
          .fill(notice.severity === 'error' ? '#D93026' :
            (notice.severity === 'warning' ? '#B26B00' : '#1F7A1F'))
        Text(notice.title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#111111')
          .layoutWeight(1)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')

      if (this.noticeMessage(notice).length > 0) {
        Text(this.noticeMessage(notice))
          .fontSize(12)
          .fontColor('#5A5A5A')
          .width('100%')
          .maxLines(4)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }

      if (this.inputForm(notice) !== null) {
        InputRequestCard({
          form: this.inputForm(notice) as InputRequestForm,
          submitting: this.actionBusy,
          onSubmit: (actionId: string, payload: InputAnswersPayload) => {
            this.respond(notice, actionId, payload);
          }
        })
      } else {
        Row({ space: 8 }) {
          ForEach(notice.actions ?? [], (action: NoticeActionDto) => {
            Button(action.label)
              .height(32)
              .fontSize(12)
              .enabled(!this.actionBusy)
              .backgroundColor(action.style === 'danger' ? '#D93026' :
                (action.style === 'primary' ? '#000000' : '#EDEDED'))
              .fontColor(action.style === 'primary' || action.style === 'danger' ? '#FFFFFF' : '#111111')
              .onClick(() => {
                this.respond(notice, action.actionId);
              })
          })
        }
        .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(12)
    .borderRadius(10)
    .backgroundColor(notice.severity === 'error' ? '#FDF1F0' :
      (notice.severity === 'warning' ? '#FDF6EC' : '#F4F8F2'))
  }

  @Builder
  rowView(row: TimelineRow) {
    if (row.kind === TimelineRowKind.UserMessage) {
      Row() {
        Blank()
        Column({ space: 4 }) {
          if (parseQuestionReply(row.body) !== null) {
            Column({ space: 6 }) {
              ForEach(parseQuestionReply(row.body) as QuestionAnswer[], (item: QuestionAnswer) => {
                Column({ space: 2 }) {
                  Text(`问：${item.question}`)
                    .fontSize(12)
                    .fontColor('#BDBDBD')
                    .width('100%')
                  Text(`答：${item.answer}`)
                    .fontSize(14)
                    .fontColor('#FFFFFF')
                    .width('100%')
                }
                .alignItems(HorizontalAlign.Start)
                .width('100%')
                .padding(8)
                .borderRadius(6)
                .backgroundColor('#3A3A3A')
              }, (item: QuestionAnswer, index: number) => `qa-${row.id}-${index}`)
            }
            .width('100%')
          } else {
            Text(row.body)
              .fontSize(15)
              .fontColor('#FFFFFF')
          }
          if (row.attachments.length > 0) {
            Column({ space: 6 }) {
              ForEach(row.attachments, (attachment: AttachmentRefDto) => {
                AttachmentImage({
                  serverUrl: this.session !== null ? this.session.serverUrl : '',
                  token: this.session !== null ? this.session.accessToken : '',
                  sessionId: this.initial !== null ? this.initial.id : '',
                  attachment: attachment
                })
              }, (attachment: AttachmentRefDto) => attachment.fileId)
            }
          }
          if (row.timeLabel.length > 0) {
            Text(row.timeLabel)
              .fontSize(10)
              .fontColor('#D0D0D0')
          }
        }
        .alignItems(HorizontalAlign.End)
        .padding(12)
        .borderRadius(12)
        .backgroundColor('#1A1A1A')
        .constraintSize({ maxWidth: '78%' })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 6, bottom: 6 })
    } else if (row.kind === TimelineRowKind.AgentMessage) {
      Row() {
        Column({ space: 4 }) {
          MarkdownView({ content: row.body })
          if (row.attachments.length > 0) {
            Column({ space: 6 }) {
              ForEach(row.attachments, (attachment: AttachmentRefDto) => {
                AttachmentImage({
                  serverUrl: this.session !== null ? this.session.serverUrl : '',
                  token: this.session !== null ? this.session.accessToken : '',
                  sessionId: this.initial !== null ? this.initial.id : '',
                  attachment: attachment
                })
              }, (attachment: AttachmentRefDto) => attachment.fileId)
            }
          }
          if (row.timeLabel.length > 0) {
            Text(row.timeLabel)
              .fontSize(10)
              .fontColor('#9A9A9A')
          }
        }
        .alignItems(HorizontalAlign.Start)
        .padding(12)
        .borderRadius(12)
        .backgroundColor('#F5F5F5')
        .constraintSize({ maxWidth: '82%' })
        Blank()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 6, bottom: 6 })
    } else if (row.kind === TimelineRowKind.ToolCall) {
      Column({ space: 6 }) {
        Row({ space: 6 }) {
          Text(row.command.length > 0 ? `$ ${row.command}` : (row.title.length > 0 ? row.title : '工具调用'))
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontFamily('monospace')
            .fontColor('#3A3A3A')
            .layoutWeight(1)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (row.status.length > 0 && row.status !== 'done') {
            Text(row.status)
              .fontSize(10)
              .fontColor('#8A8A8A')
          }
        }
        .width('100%')
        if (row.body.length > 0) {
          Text(row.body)
            .fontSize(12)
            .fontFamily('monospace')
            .fontColor('#5A5A5A')
            .maxLines(8)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .padding(8)
            .borderRadius(6)
            .backgroundColor('#E6E6E6')
            .copyOption(CopyOptions.LocalDevice)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(12)
      .margin({ left: 16, right: 16, top: 4, bottom: 4 })
      .borderRadius(10)
      .backgroundColor('#EFEFEF')
    } else {
      if (row.body.length > 0 || row.systemLabel.length > 0) {
        Text(row.body.length > 0 ? row.body : row.systemLabel)
          .fontSize(11)
          .fontColor('#8A8A8A')
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ left: 24, right: 24, top: 6, bottom: 6 })
      }
    }
  }

  build() {
    Stack() {
    if (this.showTerminal) {
      TerminalScreen({
        session: this.session,
        sessionId: this.initial !== null ? this.initial.id : '',
        onBack: () => {
          this.showTerminal = false;
        }
      })
    } else {
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
        Column({ space: 2 }) {
          Text(this.title.length > 0 ? this.title : '会话')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#000000')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Row({ space: 4 }) {
            Circle().width(6).height(6).fill(this.statusTint)
            Text(this.statusText)
              .fontSize(11)
              .fontColor(this.statusTint)
            Text('·')
              .fontSize(11)
              .fontColor('#B0B0B0')
            Circle().width(6).height(6).fill(this.liveConnected ? '#1F7A1F' : '#B0B0B0')
            Text(this.liveText)
              .fontSize(11)
              .fontColor(this.liveConnected ? '#1F7A1F' : '#8A8A8A')
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button('更多')
          .height(30)
          .fontSize(12)
          .backgroundColor('#EDEDED')
          .fontColor('#111111')
          .bindMenu([
            {
              value: this.takeover ? '释放接管' : '接管会话',
              action: () => {
                this.toggleTakeover();
              }
            },
            {
              value: '打断当前运行',
              action: () => {
                this.interruptRun();
              }
            },
            {
              value: '终端',
              action: () => {
                this.showTerminal = true;
              }
            },
            {
              value: '运行参数',
              action: () => {
                this.openSettings();
              }
            }
          ])
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      if (this.notices.length > 0) {
        Column({ space: 8 }) {
          ForEach(this.notices, (notice: NoticeDto) => {
            this.noticeCard(notice)
          }, (notice: NoticeDto) => notice.noticeId)
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 8 })
      }

      if (this.loading) {
        Column() {
          LoadingProgress().width(40).height(40)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.errorMessage.length > 0) {
        Column({ space: 12 }) {
          Text(this.errorMessage)
            .fontSize(14)
            .fontColor('#D93026')
            .textAlign(TextAlign.Center)
          Button('重试')
            .height(36)
            .onClick(() => {
              this.load();
            })
        }
        .layoutWeight(1)
        .width('100%')
        .padding(24)
        .justifyContent(FlexAlign.Center)
      } else if (this.rows.length === 0) {
        Column() {
          Text('还没有消息')
            .fontSize(14)
            .fontColor('#8A8A8A')
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        if (this.hasMore) {
          Row() {
            Button(this.loadingOlder ? '加载中…' : '加载更早的消息')
              .height(32)
              .fontSize(12)
              .backgroundColor('#F2F2F2')
              .fontColor('#333333')
              .enabled(!this.loadingOlder)
              .onClick(() => {
                this.loadOlder();
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: 4, bottom: 4 })
        }

        List({ space: 2 }) {
          ForEach(this.rows, (row: TimelineRow) => {
            ListItem() {
              this.rowView(row)
            }
          }, (row: TimelineRow) => row.id)
        }
        .layoutWeight(1)
        .width('100%')
      }

      if (this.actionError.length > 0) {
        Text(this.actionError)
          .fontSize(12)
          .fontColor('#D93026')
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 4 })
      }

      if (!this.takeover) {
        Text('接管后才能发送消息')
          .fontSize(11)
          .fontColor('#B26B00')
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 4 })
      }

      if (this.pendingNames.length > 0) {
        Row({ space: 6 }) {
          ForEach(this.pendingNames, (name: string, index: number) => {
            Row({ space: 4 }) {
              Text(`附件 · ${name}`)
                .fontSize(11)
                .fontColor('#444444')
                .maxLines(1)
              Text('×')
                .fontSize(13)
                .fontColor('#D93026')
                .onClick(() => {
                  this.controller.removePendingAttachment(index);
                  this.pendingNames = this.controller.getPendingAttachments()
                    .map((attachment: UploadedAttachment) => attachment.name);
                })
            }
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .borderRadius(8)
            .backgroundColor('#F2F2F2')
          }, (name: string, index: number) => `${name}-${index}`)
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 4 })
      }

      Row({ space: 8 }) {
        Button(this.uploading ? '…' : '＋')
          .width(42)
          .height(42)
          .fontSize(18)
          .backgroundColor('#F5F5F5')
          .fontColor('#333333')
          .enabled(!this.uploading)
          .onClick(() => {
            this.pickAttachment();
          })
        TextArea({ placeholder: this.takeover ? '发送消息…' : '先点上方「接管」', text: this.draft })
          .layoutWeight(1)
          .height(42)
          .fontSize(14)
          .backgroundColor('#F5F5F5')
          .borderRadius(10)
          .onChange((value: string) => {
            this.draft = value;
          })
        Button(this.actionBusy ? '发送中' : '发送')
          .height(42)
          .fontSize(14)
          .enabled(!this.actionBusy && this.takeover &&
            (this.draft.trim().length > 0 || this.pendingNames.length > 0))
          .onClick(() => {
            this.send();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 12 })
      .border({ width: { top: 1 }, color: '#EFEFEF' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
    }

      if (this.showSettings) {
        Column({ space: 10 }) {
          Row() {
            Text('运行参数')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#000000')
              .layoutWeight(1)
            Button('关闭')
              .height(28)
              .fontSize(12)
              .backgroundColor('#F2F2F2')
              .fontColor('#111111')
              .onClick(() => {
                this.showSettings = false;
              })
          }
          .width('100%')

          Text(this.runtimeSummary)
            .fontSize(13)
            .fontColor('#333333')
            .width('100%')

          ForEach(this.selectionLines, (line: string) => {
            Text(line)
              .fontSize(13)
              .fontColor('#5A5A5A')
              .width('100%')
          }, (line: string) => line)

          if (this.selectionLines.length === 0) {
            Text('该会话暂无可切换的运行参数；模型 / 权限列表需要在线 Connector 才能获取。')
              .fontSize(12)
              .fontColor('#8A8A8A')
              .width('100%')
          }

          Button('刷新')
            .height(32)
            .fontSize(12)
            .margin({ top: 4 })
            .onClick(() => {
              this.openSettings();
            })
        }
        .width('86%')
        .padding(16)
        .borderRadius(12)
        .backgroundColor('#FFFFFF')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#33000000')
    .alignContent(Alignment.Center)
  }
}
