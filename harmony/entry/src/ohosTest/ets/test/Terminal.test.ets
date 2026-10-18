import { describe, expect, it } from '@ohos/hypium';
import { TerminalBuffer } from '../../../main/ets/model/TerminalBuffer';

export default function terminalTest() {
  describe('TerminalBuffer', () => {
    it('renders plain text', 0, () => {
      const buffer = new TerminalBuffer(20, 3);
      buffer.applyText('hello');
      const spans = buffer.rowSpans(0);
      expect(spans.length > 0).assertTrue();
      expect(spans[0].text.trim()).assertEqual('hello');
    });
    it('keeps scrollback after scrolling', 0, () => {
      const buffer = new TerminalBuffer(20, 2);
      buffer.applyText('one\r\ntwo\r\nthree\r\nfour');
      expect(buffer.history.length > 0).assertTrue();
      buffer.scrollUp(1);
      expect(buffer.scrollOffset).assertEqual(1);
      buffer.scrollDown(1);
      expect(buffer.scrollOffset).assertEqual(0);
    });
    it('visible text includes content', 0, () => {
      const buffer = new TerminalBuffer(20, 2);
      buffer.applyText('alpha\r\nbeta');
      expect(buffer.visibleText().includes('alpha')).assertTrue();
    });
  });
}
