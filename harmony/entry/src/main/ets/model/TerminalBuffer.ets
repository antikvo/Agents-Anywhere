import { util } from '@kit.ArkTS';

export interface TermCell {
  ch: string;
  fg: number;
  bold: boolean;
}

export interface TermSpan {
  text: string;
  fg: number;
  bold: boolean;
}

const DEFAULT_FG: number = 7;
const MAX_HISTORY_ROWS: number = 2000;

function blankCell(): TermCell {
  return { ch: ' ', fg: DEFAULT_FG, bold: false };
}

function blankRow(cols: number): TermCell[] {
  const row: TermCell[] = [];
  for (let i = 0; i < cols; i++) {
    row.push(blankCell());
  }
  return row;
}

/**
 * 最小 VT100/ANSI 解析器：光标移动、擦除、SGR 颜色、滚动。
 * 只保留可见屏幕（无 scrollback），够首版终端展示用。
 */
export class TerminalBuffer {
  cols: number;
  rows: number;
  grid: TermCell[][];
  history: TermCell[][] = [];
  scrollOffset: number = 0;
  cursorRow: number = 0;
  cursorCol: number = 0;
  private fg: number = DEFAULT_FG;
  private bold: boolean = false;
  private savedRow: number = 0;
  private savedCol: number = 0;
  private pending: string = '';
  private decoder: util.TextDecoder = util.TextDecoder.create('utf-8');

  constructor(cols: number = 80, rows: number = 30) {
    this.cols = cols;
    this.rows = rows;
    this.grid = [];
    for (let r = 0; r < rows; r++) {
      this.grid.push(blankRow(cols));
    }
  }

  resize(cols: number, rows: number): void {
    const next: TermCell[][] = [];
    for (let r = 0; r < rows; r++) {
      const source: TermCell[] | undefined = this.grid[r];
      const row: TermCell[] = [];
      for (let c = 0; c < cols; c++) {
        row.push(source !== undefined && c < source.length ? source[c] : blankCell());
      }
      next.push(row);
    }
    this.cols = cols;
    this.rows = rows;
    this.grid = next;
    this.cursorRow = Math.min(this.cursorRow, rows - 1);
    this.cursorCol = Math.min(this.cursorCol, cols - 1);
  }

  applyBytes(bytes: Uint8Array): void {
    if (bytes.length === 0) {
      return;
    }
    const text: string = this.decoder.decodeToString(bytes);
    this.scrollOffset = 0;
    this.feed(text);
  }

  applyText(text: string): void {
    this.scrollOffset = 0;
    this.feed(text);
  }

  clear(): void {
    for (let r = 0; r < this.rows; r++) {
      this.grid[r] = blankRow(this.cols);
    }
    this.cursorRow = 0;
    this.cursorCol = 0;
    this.pending = '';
    this.scrollOffset = 0;
  }

  /**
   * 当前可视区域文本（考虑 scrollOffset），用于复制。
   */
  visibleText(): string {
    const lines: string[] = [];
    const historyCount: number = this.history.length;
    const offset: number = Math.min(this.scrollOffset, historyCount);
    for (let r = 0; r < this.rows; r++) {
      const globalIndex: number = historyCount - offset + r;
      let cells: TermCell[];
      if (globalIndex < historyCount) {
        cells = this.history[globalIndex];
      } else {
        const gridIndex: number = globalIndex - historyCount;
        cells = gridIndex >= 0 && gridIndex < this.rows ? this.grid[gridIndex] : blankRow(this.cols);
      }
      let line: string = '';
      for (let c = 0; c < this.cols; c++) {
        line += cells[c].ch;
      }
      lines.push(line.replace(/\s+$/, ''));
    }
    while (lines.length > 0 && lines[lines.length - 1].length === 0) {
      lines.pop();
    }
    while (lines.length > 0 && lines[0].length === 0) {
      lines.shift();
    }
    return lines.join('\n');
  }

  scrollUp(lines: number): void {
    const maxOffset: number = this.history.length;
    this.scrollOffset = Math.min(maxOffset, this.scrollOffset + lines);
  }

  scrollDown(lines: number): void {
    this.scrollOffset = Math.max(0, this.scrollOffset - lines);
  }

  scrollToBottom(): void {
    this.scrollOffset = 0;
  }

  /**
   * 可视行（0 = 顶部）。scrollOffset > 0 时显示历史缓冲。
   */
  visibleRowSpans(screenRow: number): TermSpan[] {
    const historyCount: number = this.history.length;
    const offset: number = Math.min(this.scrollOffset, historyCount);
    const globalIndex: number = historyCount - offset + screenRow;
    let cells: TermCell[];
    if (globalIndex < historyCount) {
      cells = this.history[globalIndex];
    } else {
      const gridIndex: number = globalIndex - historyCount;
      cells = gridIndex >= 0 && gridIndex < this.rows ? this.grid[gridIndex] : blankRow(this.cols);
    }
    return this.spansOfRow(cells);
  }

  rowSpans(rowIndex: number): TermSpan[] {
    return this.spansOfRow(this.grid[rowIndex]);
  }

  private spansOfRow(cells: TermCell[]): TermSpan[] {
    const spans: TermSpan[] = [];
    let current: TermSpan | null = null;
    for (let c = 0; c < this.cols; c++) {
      const cell: TermCell = cells[c];
      if (current === null || current.fg !== cell.fg || current.bold !== cell.bold) {
        current = { text: cell.ch, fg: cell.fg, bold: cell.bold };
        spans.push(current);
      } else {
        current.text += cell.ch;
      }
    }
    while (spans.length > 0) {
      const last: TermSpan = spans[spans.length - 1];
      if (last.text.trim().length === 0 && last.fg === DEFAULT_FG && !last.bold) {
        spans.pop();
      } else {
        break;
      }
    }
    return spans;
  }

  private feed(text: string): void {
    const data: string = this.pending + text;
    this.pending = '';
    let i: number = 0;
    while (i < data.length) {
      const ch: string = data.charAt(i);
      const code: number = data.charCodeAt(i);
      if (code === 0x1b) {
        const consumed: number = this.parseEscape(data, i);
        if (consumed < 0) {
          this.pending = data.substring(i);
          return;
        }
        i += consumed;
        continue;
      }
      if (ch === '\r') {
        this.cursorCol = 0;
        i++;
        continue;
      }
      if (ch === '\n') {
        this.newline();
        i++;
        continue;
      }
      if (ch === '\b') {
        if (this.cursorCol > 0) {
          this.cursorCol--;
        }
        i++;
        continue;
      }
      if (ch === '\t') {
        const next: number = (Math.floor(this.cursorCol / 8) + 1) * 8;
        this.cursorCol = Math.min(next, this.cols - 1);
        i++;
        continue;
      }
      if (code < 0x20 || code === 0x7f) {
        i++;
        continue;
      }
      this.putChar(ch);
      i++;
    }
  }

  private putChar(ch: string): void {
    if (this.cursorCol >= this.cols) {
      this.cursorCol = 0;
      this.newline();
    }
    const row: TermCell[] = this.grid[this.cursorRow];
    row[this.cursorCol] = { ch: ch, fg: this.fg, bold: this.bold };
    this.cursorCol++;
    if (this.cursorCol >= this.cols) {
      this.cursorCol = 0;
      this.newline();
    }
  }

  private newline(): void {
    this.cursorRow++;
    if (this.cursorRow >= this.rows) {
      const shifted: TermCell[] | undefined = this.grid.shift();
      if (shifted !== undefined) {
        this.history.push(shifted);
        if (this.history.length > MAX_HISTORY_ROWS) {
          this.history.shift();
        }
      }
      this.grid.push(blankRow(this.cols));
      this.cursorRow = this.rows - 1;
    }
  }

  /**
   * 返回序列总长度；-1 表示序列被截断，需要等待后续数据。
   */
  private parseEscape(data: string, start: number): number {
    if (start + 1 >= data.length) {
      return -1;
    }
    const next: string = data.charAt(start + 1);
    if (next === '[') {
      let i: number = start + 2;
      while (i < data.length) {
        const code: number = data.charCodeAt(i);
        if (code >= 0x40 && code <= 0x7e) {
          this.applyCsi(data.substring(start + 2, i), String.fromCharCode(code));
          return i - start + 1;
        }
        i++;
      }
      return -1;
    }
    if (next === ']') {
      let i: number = start + 2;
      while (i < data.length) {
        const code: number = data.charCodeAt(i);
        if (code === 0x07) {
          return i - start + 1;
        }
        if (code === 0x1b && i + 1 < data.length && data.charAt(i + 1) === '\\') {
          return i - start + 2;
        }
        i++;
      }
      return -1;
    }
    if (next === '(' || next === ')' || next === '#' || next === '%') {
      if (start + 2 >= data.length) {
        return -1;
      }
      return 3;
    }
    if (next === '7') {
      this.savedRow = this.cursorRow;
      this.savedCol = this.cursorCol;
      return 2;
    }
    if (next === '8') {
      this.cursorRow = this.savedRow;
      this.cursorCol = this.savedCol;
      return 2;
    }
    return 2;
  }

  private applyCsi(rawParams: string, final: string): void {
    const params: number[] = [];
    const cleaned: string = rawParams.replace(/[?>=!]/g, '');
    if (cleaned.length > 0) {
      cleaned.split(';').forEach((part: string) => {
        const value: number = part.length === 0 ? 0 : Number(part);
        params.push(Number.isNaN(value) ? 0 : value);
      });
    }
    const first: number = params.length > 0 ? params[0] : 0;
    const second: number = params.length > 1 ? params[1] : 0;
    if (final === 'A') {
      this.cursorRow = Math.max(0, this.cursorRow - Math.max(1, first));
    } else if (final === 'B') {
      this.cursorRow = Math.min(this.rows - 1, this.cursorRow + Math.max(1, first));
    } else if (final === 'C') {
      this.cursorCol = Math.min(this.cols - 1, this.cursorCol + Math.max(1, first));
    } else if (final === 'D') {
      this.cursorCol = Math.max(0, this.cursorCol - Math.max(1, first));
    } else if (final === 'E') {
      this.cursorRow = Math.min(this.rows - 1, this.cursorRow + Math.max(1, first));
      this.cursorCol = 0;
    } else if (final === 'F') {
      this.cursorRow = Math.max(0, this.cursorRow - Math.max(1, first));
      this.cursorCol = 0;
    } else if (final === 'G') {
      this.cursorCol = Math.min(this.cols - 1, Math.max(1, first) - 1);
    } else if (final === 'd') {
      this.cursorRow = Math.min(this.rows - 1, Math.max(1, first) - 1);
    } else if (final === 'H' || final === 'f') {
      this.cursorRow = Math.min(this.rows - 1, Math.max(1, first) - 1);
      this.cursorCol = Math.min(this.cols - 1, Math.max(1, second) - 1);
    } else if (final === 'J') {
      this.eraseDisplay(first);
    } else if (final === 'K') {
      this.eraseLine(first);
    } else if (final === 'm') {
      this.applySgr(params);
    } else if (final === 's') {
      this.savedRow = this.cursorRow;
      this.savedCol = this.cursorCol;
    } else if (final === 'u') {
      this.cursorRow = this.savedRow;
      this.cursorCol = this.savedCol;
    } else if (final === 'X') {
      const count: number = Math.max(1, first);
      const row: TermCell[] = this.grid[this.cursorRow];
      for (let c = this.cursorCol; c < Math.min(this.cols, this.cursorCol + count); c++) {
        row[c] = blankCell();
      }
    } else if (final === 'P') {
      const count: number = Math.max(1, first);
      const row: TermCell[] = this.grid[this.cursorRow];
      for (let c = this.cursorCol; c < this.cols - count; c++) {
        row[c] = row[c + count];
      }
      for (let c = this.cols - count; c < this.cols; c++) {
        row[c] = blankCell();
      }
    }
  }

  private eraseDisplay(mode: number): void {
    if (mode === 2 || mode === 3) {
      for (let r = 0; r < this.rows; r++) {
        this.grid[r] = blankRow(this.cols);
      }
      return;
    }
    if (mode === 0) {
      this.eraseLine(0);
      for (let r = this.cursorRow + 1; r < this.rows; r++) {
        this.grid[r] = blankRow(this.cols);
      }
    } else if (mode === 1) {
      this.eraseLine(1);
      for (let r = 0; r < this.cursorRow; r++) {
        this.grid[r] = blankRow(this.cols);
      }
    }
  }

  private eraseLine(mode: number): void {
    const row: TermCell[] = this.grid[this.cursorRow];
    if (mode === 2) {
      for (let c = 0; c < this.cols; c++) {
        row[c] = blankCell();
      }
      return;
    }
    if (mode === 0) {
      for (let c = this.cursorCol; c < this.cols; c++) {
        row[c] = blankCell();
      }
    } else if (mode === 1) {
      for (let c = 0; c <= this.cursorCol && c < this.cols; c++) {
        row[c] = blankCell();
      }
    }
  }

  private applySgr(params: number[]): void {
    if (params.length === 0) {
      this.fg = DEFAULT_FG;
      this.bold = false;
      return;
    }
    let i: number = 0;
    while (i < params.length) {
      const p: number = params[i];
      if (p === 0) {
        this.fg = DEFAULT_FG;
        this.bold = false;
      } else if (p === 1) {
        this.bold = true;
      } else if (p === 22) {
        this.bold = false;
      } else if (p >= 30 && p <= 37) {
        this.fg = p - 30;
      } else if (p === 39) {
        this.fg = DEFAULT_FG;
      } else if (p >= 90 && p <= 97) {
        this.fg = p - 90 + 8;
      } else if (p === 38 && i + 1 < params.length) {
        const mode: number = params[i + 1];
        if (mode === 5 && i + 2 < params.length) {
          this.fg = params[i + 2];
          i += 2;
        } else if (mode === 2 && i + 4 < params.length) {
          this.fg = this.nearestColor(params[i + 2], params[i + 3], params[i + 4]);
          i += 4;
        }
      }
      i++;
    }
  }

  private nearestColor(r: number, g: number, b: number): number {
    if (r > 200 && g > 200 && b > 200) {
      return 15;
    }
    const index: number = (r < 128 ? 0 : 1) * 4 + (g < 128 ? 0 : 1) * 2 + (b < 128 ? 0 : 1);
    return index === 0 ? 7 : index;
  }
}

const BASE_COLORS: string[] = [
  '#000000', '#C03030', '#2E9E4F', '#B8860B',
  '#3465A4', '#8E44AD', '#2C8C99', '#D0D0D0',
  '#7F7F7F', '#FF6B6B', '#55D187', '#FFD166',
  '#6FA8FF', '#C792EA', '#57C7D4', '#FFFFFF'
];

export function terminalColor(fg: number): string {
  if (fg >= 0 && fg < 16) {
    return BASE_COLORS[fg];
  }
  if (fg >= 16 && fg <= 231) {
    const index: number = fg - 16;
    const r: number = Math.floor(index / 36);
    const g: number = Math.floor((index % 36) / 6);
    const b: number = index % 6;
    const channel = (v: number): number => v === 0 ? 0 : 55 + v * 40;
    return `rgb(${channel(r)},${channel(g)},${channel(b)})`;
  }
  if (fg >= 232 && fg <= 255) {
    const level: number = 8 + (fg - 232) * 10;
    return `rgb(${level},${level},${level})`;
  }
  return BASE_COLORS[7];
}
