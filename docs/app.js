'use strict';
const $ = id => document.getElementById(id);
const number = value => Number(value ?? 0).toLocaleString('zh-TW');
const formatter = new Intl.DateTimeFormat('zh-TW', { timeZone: 'Asia/Taipei', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false });
const fullFormatter = new Intl.DateTimeFormat('zh-TW', { timeZone: 'Asia/Taipei', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false });
const time = (seconds, full = false) => seconds == null ? '尚無紀錄' : (full ? fullFormatter : formatter).format(new Date(seconds * 1000));
let offset = 0, currentUsers = [], activeUser = null, nextCursor = null, controller, historyController;
let requestSerial = 0;
const pageSize = 50;
function element(tag, text, className) {
  const el = document.createElement(tag);
  if (text !== undefined) el.textContent = text;
  if (className) el.className = className;
  return el;
}
function cell(row, text, className) { const td = element('td', text, className); row.append(td); return td; }
function empty(target, message, columns) {
  const row = element('tr'); const td = cell(row, message, 'empty'); td.colSpan = columns;
  target.replaceChildren(row);
}
function parameters() {
  const params = new URLSearchParams({ days: $('days').value });
  if ($('script').value) params.set('script', $('script').value);
  return params;
}
async function api(path, params, signal) {
  const response = await fetch(`${window.ANALYTICS_API}${path}?${params}`, { signal, cache: 'no-store', credentials: 'omit' });
  if (!response.ok) throw new Error(response.status === 404 ? '公開統計 API 尚未部署，請先更新 Cloudflare Worker。' : `統計服務暫時無法讀取（HTTP ${response.status}），請稍後再試。`);
  return response.json();
}
function dailySeries(source) {
  const count = $('days').value === '7' ? 7 : 30;
  const now = Date.now() + 8 * 3600000;
  const day = Math.floor(now / 86400000);
  const byDay = new Map(source.map(item => [item.day, item]));
  return Array.from({ length: count }, (_, index) => {
    const key = new Date((day - count + index + 1) * 86400000).toISOString().slice(0, 10);
    return byDay.get(key) || { day: key, executions: 0, accounts: 0 };
  });
}
function renderSummary(data) {
  $('executions').textContent = number(data.executions);
  $('accounts').textContent = number(data.accounts);
  $('returning').textContent = number(data.returning_accounts);
  $('latest').textContent = time(data.last_seen);
  const daily = dailySeries(data.daily);
  const max = Math.max(1, ...daily.map(item => item.executions));
  $('chart').replaceChildren(); $('daily').replaceChildren();
  daily.forEach((item, index) => {
    const group = element('div', undefined, 'bar-group');
    const label = `${item.day}：${number(item.executions)} 次，${number(item.accounts)} 個帳號`;
    group.title = label; group.setAttribute('role', 'img'); group.setAttribute('aria-label', label);
    const bar = element('div', undefined, 'bar');
    bar.style.height = `${item.executions / max * 100}%`;
    if (!item.executions) bar.style.background = '#e6edf6';
    group.append(bar);
    if (index === 0 || index === daily.length - 1 || index % (daily.length < 10 ? 1 : 7) === 0) group.append(element('span', item.day.slice(5).replace('-', '/'), 'bar-label'));
    $('chart').append(group);
    const row = element('tr'); cell(row, item.day); cell(row, number(item.executions)); cell(row, number(item.accounts)); $('daily').append(row);
  });
  $('trend-label').textContent = `最近 ${daily.length} 天`;
}
function renderUsers(data) {
  currentUsers = data.users;
  $('users').replaceChildren();
  if (!data.users.length) empty($('users'), '這個篩選範圍內尚無回報紀錄。', 5);
  for (const user of data.users) {
    const row = element('tr');
    const td = cell(row);
    const button = element('button', user.user_id, 'user-button'); button.type = 'button';
    button.addEventListener('click', () => openUser(user.user_id)); td.append(button);
    if (user.executions > 1) td.append(element('span', '重複使用', 'repeat'));
    cell(row).append(element('span', number(user.executions), 'number'));
    cell(row, number(user.scripts)); cell(row, time(user.first_seen)); cell(row, time(user.last_seen));
    $('users').append(row);
  }
  $('range').textContent = data.total ? `${number(data.offset + 1)}–${number(data.offset + data.users.length)} / ${number(data.total)} 個帳號` : '0 個帳號';
  $('prev').disabled = offset === 0; $('next').disabled = !data.has_more;
  $('export').disabled = !data.users.length;
}
async function refresh(reset = false) {
  if (reset) offset = 0;
  controller?.abort(); controller = new AbortController();
  const signal = controller.signal;
  const serial = ++requestSerial;
  $('refresh').disabled = true; $('updated').textContent = '更新中…';
  $('error').hidden = true; $('export').disabled = true;
  const params = parameters();
  const userParams = new URLSearchParams(params);
  userParams.set('offset', offset); userParams.set('limit', pageSize); userParams.set('sort', $('sort').value);
  if ($('search').value.trim()) userParams.set('user_id', $('search').value.trim());
  try {
    const [summary, users] = await Promise.all([api('/api/summary', params, signal), api('/api/users', userParams, signal)]);
    renderSummary(summary); renderUsers(users);
    $('updated').textContent = `更新於 ${time(summary.generated_at)}`;
  } catch (error) {
    if (error.name === 'AbortError') return;
    $('error').textContent = error.message; $('error').hidden = false;
    $('updated').textContent = '讀取失敗，資料未更新';
    currentUsers = [];
    empty($('users'), '暫時無法取得資料，請按重新整理。', 5);
    $('prev').disabled = true; $('next').disabled = true; $('range').textContent = '尚無可用資料';
    for (const id of ['executions', 'accounts', 'returning', 'latest']) $(id).textContent = '—';
    $('chart').replaceChildren(element('span', '統計服務尚未連線')); $('daily').replaceChildren();
  } finally { if (serial === requestSerial) $('refresh').disabled = false; }
}
async function openUser(id) {
  activeUser = id; nextCursor = null;
  $('detail-title').textContent = `帳號 ${id}`;
  $('profile').href = `https://www.roblox.com/users/${encodeURIComponent(id)}/profile`;
  $('history').replaceChildren(); $('history-status').textContent = '';
  if (!$('detail').open) $('detail').showModal();
  await history(true);
}
async function history(reset = false) {
  historyController?.abort(); historyController = new AbortController();
  const signal = historyController.signal;
  const id = activeUser;
  $('more-history').hidden = true; $('history-status').textContent = '讀取中…';
  const params = parameters(); params.set('user_id', id); params.set('limit', 50);
  if (!reset && nextCursor) params.set('cursor', nextCursor);
  try {
    const data = await api('/api/events', params, signal);
    if (activeUser !== id || signal.aborted) return;
    if (reset) $('history').replaceChildren();
    if (!data.events.length && reset) empty($('history'), '這個範圍內沒有執行紀錄。', 2);
    for (const event of data.events) {
      const row = element('tr'); cell(row, time(event.created_at, true)); cell(row, event.script); $('history').append(row);
    }
    nextCursor = data.next_cursor;
    $('more-history').hidden = !nextCursor;
    $('history-status').textContent = nextCursor ? '' : '已顯示此範圍內的所有紀錄。';
  } catch (error) {
    if (error.name === 'AbortError') return;
    $('history-status').textContent = error.message;
    $('more-history').hidden = false; // 允許重試失敗的第一頁或下一頁。
  }
}
function closeDetail() { historyController?.abort(); activeUser = null; $('detail').close(); }
$('close-detail').addEventListener('click', closeDetail);
$('detail').addEventListener('cancel', () => { historyController?.abort(); activeUser = null; });
$('more-history').addEventListener('click', () => history(nextCursor === null));
$('refresh').addEventListener('click', () => refresh());
for (const id of ['days', 'script', 'sort']) $(id).addEventListener('change', () => refresh(true));
$('search-form').addEventListener('submit', event => { event.preventDefault(); refresh(true); });
$('clear').addEventListener('click', () => { $('search').value = ''; refresh(true); });
$('prev').addEventListener('click', () => { offset = Math.max(0, offset - pageSize); refresh(); });
$('next').addEventListener('click', () => { offset += pageSize; refresh(); });
$('export').addEventListener('click', () => {
  const rows = [['Roblox UserId', '執行次數', '腳本數', '期間內首次執行（台灣）', '期間內最近執行（台灣）'], ...currentUsers.map(user => [user.user_id, user.executions, user.scripts, time(user.first_seen, true), time(user.last_seen, true)])];
  const csv = '\uFEFF' + rows.map(row => row.map(value => `"${String(value).replaceAll('"', '""')}"`).join(',')).join('\r\n');
  const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8' }));
  const link = document.createElement('a'); link.href = url; link.download = 'roblox-usage.csv'; link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
});
setInterval(() => { if (!document.hidden && !$('detail').open) refresh(); }, 60000);
refresh();
