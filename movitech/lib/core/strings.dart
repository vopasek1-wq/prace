/// České texty aplikace na jednom místě (pro zkušební verzi bez .arb souborů).
class S {
  const S._();

  static const appName = 'Movitech';
  static const tagline = 'Interní chat pro malý tým';

  // Přihlášení
  static const signInGoogle = 'Přihlásit se přes Google';
  static const enterDemo = 'Vstoupit do demo režimu';
  static const demoBanner = 'Demo režim – data jsou jen v tomto telefonu';
  static const notAllowlisted = 'Tento účet nemá přístup. Požádejte o přidání do seznamu povolených e-mailů.';
  static const signInFailed = 'Přihlášení se nepovedlo';
  static const signOut = 'Odhlásit se';
  static const signedInAs = 'Přihlášen jako';

  // Místnosti
  static const rooms = 'Místnosti';
  static const noRooms = 'Místnosti nejsou nastavené';
  static const noRoomsHint = 'Spusťte seed skript (viz docs/SPUSTENI.md), který založí 3 místnosti.';
  static const noMessagesYet = 'Zatím žádné zprávy';
  static const photoPreview = '📷 Fotka';
  static const you = 'Vy';

  // Chat
  static const messageHint = 'Napište zprávu';
  static const send = 'Odeslat';
  static const emptyChat = 'Napište první zprávu.\nTip: podržte zprávu prstem a můžete na ni reagovat.';
  static const today = 'Dnes';
  static const yesterday = 'Včera';
  static const unknownUser = 'Neznámý';
  static const sendFailed = 'Zprávu se nepodařilo odeslat';
  static const reactionFailed = 'Reakci se nepodařilo uložit';
  static const copy = 'Kopírovat text';
  static const copied = 'Zkopírováno';
  static const reactTitle = 'Reagovat';
  static const offline = 'Offline – zprávy se odešlou po připojení';

  // Fotky
  static const attach = 'Přidat fotku';
  static const takePhoto = 'Vyfotit';
  static const fromGallery = 'Z galerie';
  static const fromDrive = 'Ze složky na Google Disku';
  static const fromDriveHint = 'Fotky ve složce „Movitech – fotky“ na hlavním Disku';
  static const uploading = 'Nahrávám…';
  static const caption = 'Popisek (nepovinný)';
  static const recognizeText = 'Přepsat text z fotky';
  static const recognizeHint = 'Rozpozná tištěný text a přidá ho pod fotku, aby šel vyhledat a zkopírovat.';
  static const recognizing = 'Nahrávám a přepisuji text…';
  static const ocrFailed = 'Text z fotky se nepodařilo přepsat, fotka se odeslala bez něj.';
  static const showMore = 'Zobrazit celý text';
  static const showLess = 'Zobrazit méně';
  static const cancel = 'Zrušit';
  static const photoLoadFailed = 'Fotku se nepodařilo načíst';
  static const retry = 'Zkusit znovu';
  static const driveEmpty =
      'Ve složce zatím nejsou žádné fotky.\nVložíte-li fotky do složky „Movitech – fotky“ na hlavním Disku, objeví se tady.';
  static const driveTitle = 'Google Disk – složka Movitech';
  static const attachSelected = 'Připojit';
  static const photoTitle = 'Fotka';

  // Hledání
  static const search = 'Hledat';
  static const searchHint = 'Hledat ve zprávách';
  static const searchPrompt = 'Zadejte hledaný text';
  static const searchNothing = 'Nic nenalezeno';
  static const searchAll = 'Všechny';
  static const searchLoading = 'Načítám zprávy…';
  static const searchLimitNote = 'Prohledává se posledních 1000 zpráv v každé místnosti.';
  static const searchTooltip = 'Vyhledávání zahrnuje jen text zpráv.';

  // Chyby
  static const genericError = 'Něco se pokazilo';
  static const setupErrorTitle = 'Aplikace není nastavená';
}
