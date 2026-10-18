import {
  InlineSpan,
  InlineStyle,
  MarkdownBlock,
  MarkdownBlockKind,
  parseInline,
  parseMarkdown
} from '../../model/Markdown';

/**
 * ArkTS 原生 Markdown 渲染（不使用 RichText / WebView）。
 * 首版覆盖标题、段落、列表、引用、分割线、围栏代码块与行内强调。
 */
@Component
export struct MarkdownView {
  content: string = '';
  @State showCodePreview: boolean = false;
  @State codePreviewText: string = '';
  @State codePreviewLanguage: string = '';
  @State showImagePreview: boolean = false;
  @State imagePreviewUrl: string = '';
  @State failedImages: string[] = [];

  @Builder
  inlineView(text: string, fontSize: number, color: string) {
    Text() {
      ForEach(parseInline(text), (span: InlineSpan) => {
        Span(span.text)
          .fontWeight(span.style === InlineStyle.Bold ? FontWeight.Bold : FontWeight.Normal)
          .fontStyle(span.style === InlineStyle.Italic ? FontStyle.Italic : FontStyle.Normal)
          .fontColor(span.style === InlineStyle.Code ? '#B04A00' :
            (span.style === InlineStyle.Link ? '#1F5FBF' : color))
          .fontFamily(span.style === InlineStyle.Code ? 'monospace' : 'HarmonyOS Sans')
      })
    }
    .fontSize(fontSize)
    .lineHeight(fontSize + 7)
    .width('100%')
  }

  @Builder
  blockView(block: MarkdownBlock) {
    if (block.kind === MarkdownBlockKind.Heading) {
      Text(block.text)
        .fontSize(block.level === 1 ? 20 : (block.level === 2 ? 18 : 16))
        .fontWeight(FontWeight.Bold)
        .fontColor('#000000')
        .width('100%')
        .margin({ top: 8, bottom: 2 })
    } else if (block.kind === MarkdownBlockKind.Code) {
      Column({ space: 4 }) {
        Row({ space: 8 }) {
          Text(block.language.length > 0 ? block.language : '代码')
            .fontSize(10)
            .fontColor('#8A8A8A')
            .layoutWeight(1)
          Text('查看')
            .fontSize(10)
            .fontColor('#3A6FD8')
            .onClick(() => {
              this.codePreviewText = block.text;
              this.codePreviewLanguage = block.language;
              this.showCodePreview = true;
            })
        }
        .width('100%')
        Text(block.text)
          .fontSize(12)
          .fontFamily('monospace')
          .fontColor('#111111')
          .lineHeight(18)
          .width('100%')
          .maxLines(12)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(10)
      .borderRadius(8)
      .backgroundColor('#F2F2F2')
      .margin({ top: 4, bottom: 4 })
    } else if (block.kind === MarkdownBlockKind.ListItem) {
      Row({ space: 6 }) {
        Text(block.ordered ? `${block.index}.` : '•')
          .fontSize(block.level > 0 ? 13 : 15)
          .fontColor('#666666')
          .width(block.ordered ? 18 : 10)
        Column() {
          this.inlineView(block.text, 15, '#111111')
        }
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .padding({ top: 2, bottom: 2, left: block.level * 16 })
    } else if (block.kind === MarkdownBlockKind.Quote) {
      Column() {
        this.inlineView(block.text, 14, '#5A5A5A')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 10, top: 4, bottom: 4 })
      .border({ width: { left: 3 }, color: '#D0D0D0' })
    } else if (block.kind === MarkdownBlockKind.Table) {
      Column() {
        ForEach(block.table ?? [], (row: string[], rowIndex: number) => {
          Row() {
            ForEach(row, (cell: string, cellIndex: number) => {
              if (rowIndex === 0) {
                Text(cell)
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#111111')
                  .layoutWeight(1)
                  .padding(6)
              } else {
                Column() {
                  this.inlineView(cell, 12, '#111111')
                }
                .layoutWeight(1)
                .padding(6)
              }
            }, (cell: string, cellIndex: number) => `cell-${rowIndex}-${cellIndex}`)
          }
          .width('100%')
          .border({ width: { bottom: 1 }, color: '#E5E5E5' })
          .backgroundColor(rowIndex === 0 ? '#F2F2F2' : '#FFFFFF')
        }, (row: string[], rowIndex: number) => `row-${rowIndex}`)
      }
      .width('100%')
      .border({ width: 1, color: '#E5E5E5' })
      .borderRadius(6)
      .margin({ top: 4, bottom: 4 })
    } else if (block.kind === MarkdownBlockKind.Image) {
      Column({ space: 4 }) {
        if (this.failedImages.includes(block.url ?? '')) {
          Row() {
            Text('图片加载失败')
              .fontSize(11)
              .fontColor('#8A8A8A')
          }
          .width('100%')
          .height(80)
          .justifyContent(FlexAlign.Center)
          .borderRadius(6)
          .backgroundColor('#F2F2F2')
        } else {
          Image(block.url ?? '')
            .width('100%')
            .constraintSize({ maxHeight: 220 })
            .objectFit(ImageFit.Contain)
            .borderRadius(6)
            .backgroundColor('#F2F2F2')
            .onError(() => {
              this.failedImages = this.failedImages.concat([block.url ?? '']);
            })
            .onClick(() => {
              this.imagePreviewUrl = block.url ?? '';
              this.showImagePreview = true;
            })
        }
        if (block.text.length > 0) {
          Text(block.text)
            .fontSize(11)
            .fontColor('#8A8A8A')
            .width('100%')
        }
      }
      .width('100%')
      .margin({ top: 4, bottom: 4 })
    } else if (block.kind === MarkdownBlockKind.Divider) {
      Divider().color('#E0E0E0').margin({ top: 8, bottom: 8 })
    } else {
      Column() {
        this.inlineView(block.text, 15, '#111111')
      }
      .width('100%')
      .padding({ top: 1, bottom: 1 })
    }
  }

  build() {
    Stack() {
      Column({ space: 2 }) {
        ForEach(parseMarkdown(this.content), (block: MarkdownBlock, index: number) => {
          this.blockView(block)
        }, (block: MarkdownBlock, index: number) => `${index}`)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.showImagePreview) {
        Column({ space: 10 }) {
          Row({ space: 8 }) {
            Text('图片')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#000000')
              .layoutWeight(1)
            Text('关闭')
              .fontSize(12)
              .fontColor('#3A6FD8')
              .onClick(() => {
                this.showImagePreview = false;
              })
          }
          .width('100%')
          Image(this.imagePreviewUrl)
            .width('100%')
            .constraintSize({ maxHeight: 560 })
            .objectFit(ImageFit.Contain)
            .borderRadius(8)
            .backgroundColor('#F2F2F2')
        }
        .width('90%')
        .padding(16)
        .borderRadius(12)
        .backgroundColor('#FFFFFF')
        .shadow({ radius: 24, color: '#33000000' })
      }

      if (this.showCodePreview) {
        Column({ space: 10 }) {
          Row({ space: 8 }) {
            Text(this.codePreviewLanguage.length > 0 ? this.codePreviewLanguage : '代码')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#000000')
              .layoutWeight(1)
            Text('关闭')
              .fontSize(12)
              .fontColor('#3A6FD8')
              .onClick(() => {
                this.showCodePreview = false;
              })
          }
          .width('100%')
          Scroll() {
            Text(this.codePreviewText)
              .fontSize(12)
              .fontFamily('monospace')
              .fontColor('#111111')
              .lineHeight(18)
              .width('100%')
              .copyOption(CopyOptions.LocalDevice)
          }
          .height(360)
          .width('100%')
          .padding(10)
          .borderRadius(8)
          .backgroundColor('#F5F5F5')
          .align(Alignment.TopStart)
        }
        .width('90%')
        .padding(16)
        .borderRadius(12)
        .backgroundColor('#FFFFFF')
        .shadow({ radius: 24, color: '#33000000' })
      }
    }
    .width('100%')
    .height(this.showCodePreview ? '100%' : undefined)
    .alignContent(Alignment.Center)
  }
}
