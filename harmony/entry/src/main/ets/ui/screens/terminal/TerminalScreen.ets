import { AuthSession } from '../../../feature/auth/AuthSessionStore';
import { TerminalController } from '../../../feature/terminal/TerminalController';
import { TermSpan, terminalColor } from '../../../model/TerminalBuffer';
import { TerminalView } from '../../../api/TerminalApi';
import { BackgroundTask } from '../../../platform/BackgroundTask';

/**
 * 终端：VT 解析 + 颜色渲染 + 输入/清屏。
 * Connector 离线时提供本地演示画面，便于验证渲染。
 */
@Component
export struct TerminalScreen {
  session: AuthSession | null = null;
  sessionId: string = '';
  onBack: () => void = () => {
  };
  private controller: TerminalController = new TerminalController();
  @State spans: TermSpan[][] = [];
  @State statusText: string = '未连接';
  @State errorMessage: string = '';
  @State inputLine: string = '';
  @State busy: boolean = false;
  @State terminals: TerminalView[] = [];
  @State currentTerminalId: string = '';

  aboutToAppear(): void {
    this.controller.onUpdate = () => {
      this.refresh();
    };
    this.controller.onStatus = (text: string) => {
      this.statusText = text;
    };
    this.refresh();
    this.start();
  }

  aboutToDisappear(): void {
    BackgroundTask.stop();
    this.controller.close();
  }

  private async start(): Promise<void> {
    const session: AuthSession | null = this.session;
    if (session === null || this.sessionId.length === 0) {
      this.errorMessage = '缺少会话信息';
      return;
    }
    this.busy = true;
    this.errorMessage = '';
    try {
      await this.controller.start(session, this.sessionId, 80, 26);
      this.syncTerminals();
      this.refresh();
      await BackgroundTask.start();
    } catch (error) {
      const message: string = (error as Error).message;
      this.errorMessage = message.toLowerCase().includes('offline') ?
        '设备离线：终端需要在线 Connector。可点「演示」查看本地渲染。' : message;
      this.statusText = '未连接';
    } finally {
      this.busy = false;
    }
  }

  private syncTerminals(): void {
    this.terminals = this.controller.getTerminals();
    const terminal: TerminalView | null = this.controller.getTerminal();
    this.currentTerminalId = terminal === null ? '' : terminal.terminalId;
  }

  private async createTerminal(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    try {
      await this.controller.createAnother(80, 26);
      this.syncTerminals();
      this.refresh();
    } catch (error) {
      this.errorMessage = (error as Error).message;
    } finally {
      this.busy = false;
    }
  }

  private refresh(): void {
    const buffer = this.controller.buffer;
    const rows: TermSpan[][] = [];
    for (let r = 0; r < buffer.rows; r++) {
      let spans: TermSpan[] = buffer.rowSpans(r);
      if (spans.length === 0) {
        spans = [{ text: ' ', fg: 7, bold: false }];
      }
      rows.push(spans);
    }
    this.spans = rows;
  }

  private rowKey(row: TermSpan[], index: number): string {
    let text: string = '';
    row.forEach((span: TermSpan) => {
      text += span.text;
    });
    return `${index}:${text}`;
  }

  private sendInput(): void {
    const text: string = this.inputLine;
    if (text.length === 0) {
      return;
    }
    this.controller.sendInput(text + '\r');
    this.inputLine = '';
  }

  private async closeTerminal(): Promise<void> {
    await this.controller.close();
    const terminal: TerminalView | null = this.controller.getTerminal();
    this.statusText = terminal === null ? '已关闭' : this.statusText;
    this.refresh();
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        Button('返回')
          .height(30)
          .fontSize(12)
          .backgroundColor('#F2F2F2')
          .fontColor('#000000')
          .onClick(() => {
            this.onBack();
          })
        Column({ space: 2 }) {
          Text('终端')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#000000')
          Text(`${this.statusText}${this.busy ? ' · 连接中' : ''}`)
            .fontSize(10)
            .fontColor('#8A8A8A')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Button('演示')
          .height(28)
          .fontSize(11)
          .backgroundColor('#F2F2F2')
          .fontColor('#111111')
          .onClick(() => {
            this.controller.demo();
          })
        Button('清屏')
          .height(28)
          .fontSize(11)
          .backgroundColor('#F2F2F2')
          .fontColor('#111111')
          .onClick(() => {
            this.controller.buffer.clear();
            this.refresh();
          })
        Button('关闭')
          .height(28)
          .fontSize(11)
          .backgroundColor('#FDF1F0')
          .fontColor('#D93026')
          .onClick(() => {
            this.closeTerminal();
          })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 8 })

      Row({ space: 6 }) {
        ForEach(this.terminals, (terminal: TerminalView) => {
          Button(`终端 ${terminal.terminalId.substring(terminal.terminalId.length - 4)}`)
            .height(26)
            .fontSize(11)
            .backgroundColor(this.currentTerminalId === terminal.terminalId ? '#000000' : '#F2F2F2')
            .fontColor(this.currentTerminalId === terminal.terminalId ? '#FFFFFF' : '#333333')
            .onClick(() => {
              this.controller.switchTo(terminal);
              this.syncTerminals();
              this.refresh();
            })
        }, (terminal: TerminalView) => terminal.terminalId)
        Button('+')
          .height(26)
          .width(36)
          .fontSize(16)
          .padding(0)
          .backgroundColor('#F2F2F2')
          .fontColor('#111111')
          .enabled(!this.busy)
          .onClick(() => {
            this.createTerminal();
          })
        Blank()
        Button('重连')
          .height(26)
          .fontSize(11)
          .backgroundColor('#F2F2F2')
          .fontColor('#111111')
          .onClick(() => {
            this.controller.reconnect();
          })
      }
      .width('100%')
      .padding({ left: 12, right: 12, bottom: 6 })

      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .fontSize(11)
          .fontColor('#D93026')
          .width('100%')
          .padding({ left: 12, right: 12, bottom: 4 })
      }

      Scroll() {
        Column() {
          ForEach(this.spans, (row: TermSpan[], rowIndex: number) => {
            Row() {
              ForEach(row, (span: TermSpan) => {
                Text(span.text)
                  .fontSize(11)
                  .fontFamily('monospace')
                  .fontColor(terminalColor(span.fg))
                  .fontWeight(span.bold ? FontWeight.Bold : FontWeight.Normal)
                  .lineHeight(15)
                  .height(15)
              }, (span: TermSpan, index: number) => `${rowIndex}-${index}`)
            }
            .width('100%')
            .height(15)
            .alignItems(VerticalAlign.Top)
          }, (row: TermSpan[], index: number) => this.rowKey(row, index))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(10)
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor('#0F1115')
      .scrollable(ScrollDirection.Vertical)

      Row({ space: 8 }) {
        TextInput({ placeholder: '输入命令…', text: this.inputLine })
          .layoutWeight(1)
          .height(38)
          .fontSize(13)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
          .onChange((value: string) => {
            this.inputLine = value;
          })
        Button('发送')
          .height(38)
          .fontSize(13)
          .enabled(this.inputLine.length > 0)
          .onClick(() => {
            this.sendInput();
          })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 10 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
