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
        if (block.language.length > 0) {
          Text(block.language)
            .fontSize(10)
            .fontColor('#8A8A8A')
            .width('100%')
        }
        Text(block.text)
          .fontSize(12)
          .fontFamily('monospace')
          .fontColor('#111111')
          .lineHeight(18)
          .width('100%')
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
        Image(block.url ?? '')
          .width('100%')
          .constraintSize({ maxHeight: 220 })
          .objectFit(ImageFit.Contain)
          .borderRadius(6)
          .backgroundColor('#F2F2F2')
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
    Column({ space: 2 }) {
      ForEach(parseMarkdown(this.content), (block: MarkdownBlock, index: number) => {
        this.blockView(block)
      }, (block: MarkdownBlock, index: number) => `${index}`)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
