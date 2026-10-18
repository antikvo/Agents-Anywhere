import { describe, expect, it } from '@ohos/hypium';
import { MarkdownBlockKind, parseInline, parseMarkdown } from '../../../main/ets/model/Markdown';

export default function markdownTest() {
  describe('parseMarkdown', () => {
    it('parses heading', 0, () => {
      const blocks = parseMarkdown('# Title');
      expect(blocks.length).assertEqual(1);
      expect(blocks[0].kind).assertEqual(MarkdownBlockKind.Heading);
      expect(blocks[0].text).assertEqual('Title');
    });
    it('parses code fence', 0, () => {
      const blocks = parseMarkdown('```ts\nconst a = 1;\n```');
      const code = blocks.find((block) => block.kind === MarkdownBlockKind.Code);
      expect(code !== undefined).assertTrue();
      expect(code?.language).assertEqual('ts');
    });
    it('parses inline bold', 0, () => {
      const spans = parseInline('a **b** c');
      const bold = spans.find((span) => span.text === 'b');
      expect(bold !== undefined).assertTrue();
    });
    it('parses list items', 0, () => {
      const blocks = parseMarkdown('- one\n- two');
      expect(blocks.filter((block) => block.kind === MarkdownBlockKind.ListItem).length).assertEqual(2);
    });
  });
}
