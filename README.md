# Lista Zakupów

Aplikacja na iPhone'a do prowadzenia list zakupów, napisana w Swift z użyciem SwiftUI i SwiftData. Obsługuje wiele list, kategorie produktów, podpowiedzi nazw, udostępnianie list plikiem oraz synchronizację wybranych list między telefonami przez Firebase.

Repozytorium: https://github.com/karmauh/shopping_list_swift

Autor: Mikołaj

## Spis treści

1. [Funkcje](#funkcje)
2. [Technologie](#technologie)
3. [Struktura projektu](#struktura-projektu)
4. [Uruchomienie projektu](#uruchomienie-projektu)
5. [Konfiguracja Firebase](#konfiguracja-firebase)
6. [Instalacja na telefonie z darmowym kontem Apple](#instalacja-na-telefonie-z-darmowym-kontem-apple)
7. [Model danych](#model-danych)
8. [Udostępnianie listy plikiem](#udostępnianie-listy-plikiem)
9. [Synchronizacja między telefonami](#synchronizacja-między-telefonami)
10. [Znane ograniczenia](#znane-ograniczenia)
11. [Licencja](#licencja)

## Funkcje

Listy i produkty:

- wiele list zakupów wyświetlanych jako karty, z przesuwaniem w lewo (duplikuj, zmień nazwę, usuń) i menu kontekstowym,
- produkty pogrupowane według kategorii, z ilością,
- oznaczanie produktu jako kupionego jednym dotknięciem wiersza, kupione trafiają na koniec listy,
- przesunięcie produktu w lewo pozwala go edytować lub usunąć,
- pasek postępu zakupów, odznaczanie wszystkich kupionych i usuwanie kupionych,
- wyszukiwanie po nazwie, ilości i nazwie kategorii,
- duplikowanie listy (kopiowane są tylko aktywne produkty, nazwa kopii jest unikalna).

Kategorie:

- dziesięć kategorii domyślnych tworzonych przy pierwszym uruchomieniu: Warzywa, Owoce, Pieczywo, Nabiał, Mięso i ryby, Napoje, Słodycze i przekąski, Mrożonki, Chemia domowa, Inne,
- własne kategorie z wyborem ikony i koloru oraz podglądem na żywo,
- zmiana kolejności przez przeciąganie,
- kategoria „Inne” jest zablokowana jako kategoria zapasowa, a usunięcie kategorii przenosi jej produkty do „Inne”.

Wygoda dodawania:

- blokada duplikatów niewrażliwa na wielkość liter i polskie znaki, z możliwością przywrócenia produktu, który jest już na liście jako kupiony,
- podpowiedzi nazw na podstawie historii ze wszystkich list, z zapamiętaną ostatnio użytą kategorią.

Udostępnianie i synchronizacja:

- eksport listy do pliku `.listazakupow` (AirDrop, Pliki, Wiadomości, Poczta) oraz udostępnianie listy jako tekstu,
- import z podglądem zmian i scalaniem według czasu edycji,
- synchronizacja wybranych list między telefonami w czasie rzeczywistym przez Firebase, z dołączaniem przez kod.

## Technologie

| Obszar              | Rozwiązanie                                                    |
| ------------------- | -------------------------------------------------------------- |
| Język i interfejs   | Swift, SwiftUI                                                 |
| Lokalna baza danych | SwiftData                                                      |
| Synchronizacja      | Firebase Authentication (logowanie anonimowe), Cloud Firestore |
| Zależności          | Firebase iOS SDK (Swift Package Manager)                       |
| Wymagany system     | iOS 18 lub nowszy                                              |
| Wymagane środowisko | Xcode w wersji obsługującej docelowy system                    |

## Struktura projektu

```
ListaZakupow/
├── App/
│   ├── ListaZakupowApp.swift
│   └── ContentView.swift
├── Models/
│   ├── ShoppingList.swift
│   ├── ShoppingItem.swift
│   ├── ProductCategory.swift
│   ├── CategoryColor.swift
│   └── ItemSection.swift
├── Services/
│   ├── DefaultCategories.swift
│   ├── CategoryService.swift
│   ├── ListService.swift
│   ├── SuggestionService.swift
│   ├── Sharing/
│   │   ├── SharedListFile.swift
│   │   ├── ListSharing.swift
│   │   ├── ListImporter.swift
│   │   └── ImportCoordinator.swift
│   └── Sync/
│       ├── AppDelegate.swift
│       └── SyncService.swift
├── Utilities/
│   ├── String+Normalization.swift
│   └── AppSettings.swift
└── Views/
    ├── Lists/
    ├── Items/
    ├── Categories/
    ├── Components/
    ├── Settings/
    └── Sharing/
```

## Uruchomienie projektu

1. Sklonuj repozytorium:

```
git clone https://github.com/karmauh/shopping_list_swift.git
```

2. Otwórz projekt `ListaZakupow.xcodeproj` w Xcode. Xcode pobierze zależności Swift Package Manager automatycznie.
3. W ustawieniach celu `ListaZakupow`, w zakładce **Signing & Capabilities**, wybierz własny zespół (Team) i zmień identyfikator aplikacji (Bundle Identifier) na własny, unikalny.
4. Dodaj plik konfiguracyjny Firebase opisany w następnej sekcji. Bez niego aplikacja nie uruchomi się poprawnie.
5. Wybierz symulator lub podłączony telefon i uruchom projekt (Cmd+R).

## Konfiguracja Firebase

Plik `ListaZakupow/GoogleService-Info.plist` jest celowo wyłączony z repozytorium przez `.gitignore`. W repozytorium znajduje się szablon `GoogleService-Info.plist.example` z podstawionymi wartościami.

1. W konsoli Firebase (console.firebase.google.com) utwórz projekt na darmowym planie Spark. Google Analytics nie jest potrzebne.
2. W sekcji **Firestore Database** utwórz bazę domyślną w wersji Standard, w trybie produkcyjnym i w lokalizacji europejskiej.
3. W sekcji **Authentication**, zakładka **Sign-in method**, włącz dostawcę **Anonymous**.
4. Zarejestruj aplikację iOS, podając identyfikator aplikacji z Xcode, i pobierz plik `GoogleService-Info.plist`.
5. Umieść plik w katalogu `ListaZakupow/` i dodaj go do celu `ListaZakupow` w Xcode (Copy items if needed).
6. W Xcode, w zakładce **Info** celu, dodaj klucz `FirebaseAppDelegateProxyEnabled` typu Boolean z wartością `NO`, a w **Build Settings** do **Other Linker Flags** dodaj `-ObjC`.
7. W konsoli, **Firestore Database, Rules**, opublikuj poniższe reguły.

Nie włączaj ograniczeń klucza API po identyfikatorze aplikacji ani App Check. Aplikacje instalowane przez AltStore mają dopisany do identyfikatora identyfikator zespołu, więc takie ograniczenia zablokowałyby działającą aplikację.

Reguły bezpieczeństwa Firestore:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function signedIn() {
      return request.auth != null;
    }

    function validCode(code) {
      return code.matches('[A-Z2-9]{5}-[A-Z2-9]{5}');
    }

    function validListData() {
      return request.resource.data.name is string
        && request.resource.data.name.size() > 0
        && request.resource.data.name.size() <= 200;
    }

    function validItemData() {
      return request.resource.data.name is string
        && request.resource.data.name.size() > 0
        && request.resource.data.name.size() <= 200
        && request.resource.data.quantity is string
        && request.resource.data.quantity.size() <= 100
        && request.resource.data.isPurchased is bool
        && request.resource.data.updatedAt is timestamp;
    }

    match /lists/{code} {
      allow get: if signedIn() && validCode(code);
      allow create, update: if signedIn() && validCode(code) && validListData();
      allow delete: if false;

      match /items/{itemId} {
        allow get, list: if signedIn() && validCode(code);
        allow create, update: if signedIn() && validCode(code) && validItemData();
        allow delete: if false;
      }
    }
  }
}
```

Darmowy plan Spark obejmuje 1 GiB danych oraz 50 000 odczytów i 20 000 zapisów dziennie. Jest to wielokrotnie więcej, niż potrzebuje aplikacja używana przez dwie osoby. Po przekroczeniu limitu Firebase wyłącza dany produkt do końca okresu rozliczeniowego, zamiast naliczać opłaty.

## Instalacja na telefonie z darmowym kontem Apple

Aplikacja nie jest w App Store. Przy darmowym koncie dewelopera (Personal Team) podpis wygasa po 7 dniach i aplikację trzeba odnawiać. Są dwie drogi.

### Xcode

1. Podłącz telefon kablem, odblokuj go i zaufaj komputerowi.
2. Na telefonie włącz tryb programisty: Ustawienia, Prywatność i ochrona, Tryb programisty.
3. Wybierz telefon jako urządzenie docelowe i uruchom projekt (Cmd+R).
4. Przy pierwszym uruchomieniu zaufaj profilowi dewelopera: Ustawienia, Ogólne, VPN i zarządzanie urządzeniem.
5. Po 7 dniach podłącz telefon i uruchom projekt ponownie.

### AltStore

AltStore pozwala odnawiać podpis bez kabla, gdy telefon i komputer są w tej samej sieci Wi-Fi, a na komputerze działa program AltServer.

1. Zainstaluj AltServer na Macu (altstore.io) z folderu Programy i uruchom go.
2. Zainstaluj AltStore na telefonie z menu AltServera (Install AltStore), korzystając z osobnego Apple ID założonego do podpisywania.
3. Zbuduj plik `.ipa`: ustaw konfigurację Release (Product, Scheme, Edit Scheme, Run, Info), zbuduj projekt, w folderze `Products/Release-iphoneos` skopiuj `ListaZakupow.app` do folderu `Payload`, skompresuj go i zmień nazwę archiwum z `Payload.zip` na `ListaZakupow.ipa`.
4. Wyślij plik na telefon, otwórz go w aplikacji Pliki i wybierz Udostępnij, AltStore.
5. Dodaj AltServer do programów uruchamianych przy logowaniu i pozostaw komputer włączony w domowej sieci. Stan odnawiania sprawdzisz w AltStore, zakładka My Apps.

Uwagi:

- AltStore dopisuje do identyfikatora aplikacji identyfikator zespołu, więc kopia zainstalowana przez AltStore jest osobną aplikacją od kopii z Xcode i ma osobną bazę danych. Listy przenosi się plikiem `.listazakupow`.
- Nie usuwaj aplikacji, jeśli podpis wygasł. Usunięcie kasuje dane. Odśwież ją w AltStore.
- AltStore nie jest narzędziem wspieranym przez Apple. Zmiany po stronie Apple mogą czasowo uniemożliwiać odświeżanie.
- Używaj wyłącznie oficjalnych wersji AltServera z altstore.io.

## Model danych

Dane lokalne przechowuje SwiftData. Trzy modele:

| Model             | Najważniejsze pola                                                                                                                            |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `ShoppingList`    | `id`, `name`, `createdAt`, `updatedAt`, `shareCode`, `nameUpdatedAt`, relacja `items`                                                         |
| `ShoppingItem`    | `id`, `name`, `quantity`, `isPurchased`, `purchasedAt`, `createdAt`, `updatedAt`, `deletedAt`, `syncedUpdatedAt`, relacje `list` i `category` |
| `ProductCategory` | `id`, `name`, `symbolName`, `colorName`, `sortOrder`, `isDefault`                                                                             |

Zasady:

- Produkty nie są usuwane fizycznie, tylko oznaczane znacznikiem `deletedAt` (miękkie usuwanie). Dzięki temu usunięcie można przekazać innemu urządzeniu.
- Każda zmiana produktu odświeża jego `updatedAt` oraz `updatedAt` listy, a czas edycji rozstrzyga konflikty przy scalaniu.
- Usunięcie listy usuwa kaskadowo jej produkty. Usunięcie kategorii przenosi produkty do kategorii „Inne”.
- Pola synchronizacji są opcjonalne, więc SwiftData migruje istniejące dane automatycznie.
- Porównywanie nazw używa klucza `comparisonKey` (usuwa wielkość liter, znaki diakrytyczne, zamienia `ł` na `l` i zwija odstępy).

## Udostępnianie listy plikiem

Format pliku `.listazakupow` to JSON zawierający wersję formatu, datę eksportu oraz listę z wszystkimi produktami, także oznaczonymi jako usunięte. Typ pliku jest zadeklarowany jako `pl.mikolaj[..].listazakupow.list` (Exported Type Identifiers w ustawieniach celu), a otwarcie pliku z AirDrop lub Plików obsługuje `onOpenURL`.

Import porównuje listy po identyfikatorze, a produkty po identyfikatorze i nazwie. Pokazuje podgląd zmian (dodane, zmienione, usunięte produkty i nowe kategorie) i pozwala scalić listę, zapisać ją jako nową albo anulować. W ustawieniach można włączyć scalanie bez pytania. Przy scalaniu wygrywa nowszy czas edycji z tolerancją jednej sekundy, a brakujące kategorie są tworzone na podstawie nazwy.

## Synchronizacja między telefonami

Synchronizacja jest włączana osobno dla każdej listy. Aplikacja nie ma kont użytkowników.

1. Menu listy, **Włącz synchronizację**: aplikacja generuje kod w formacie `XXXXX-XXXXX` (32 znaki bez mylących liter I i O) i wysyła listę z produktami do chmury.
2. Druga osoba wybiera na ekranie list ikonę dołączania i wpisuje kod. Tworzona jest lokalna kopia listy, która od tej chwili wymienia zmiany z chmurą.
3. Zmiany lokalne są zapisywane w SwiftData i wysyłane do Firestore z krótkim opóźnieniem. Nasłuch zmian zdalnych działa, gdy aplikacja jest otwarta lub wraca na pierwszy plan.
4. Zmiany wykonane bez internetu zostają oznaczone jako oczekujące (`updatedAt` nowszy niż `syncedUpdatedAt`) i wysyłają się po odzyskaniu połączenia.
5. **Przestań synchronizować** odłącza listę na tym telefonie. Lista i dane w chmurze oraz na drugim telefonie zostają nietknięte.
6. Usunięcie udostępnionej listy na jednym telefonie usuwa tylko lokalną kopię.

Struktura danych w Firestore:

```
lists/{kod}
    name, nameUpdatedAt, createdAt
lists/{kod}/items/{identyfikator produktu}
    name, quantity, isPurchased, createdAt, updatedAt,
    purchasedAt, deletedAt,
    categoryName, categorySymbol, categoryColor
```

Rozstrzyganie konfliktów: zmiana ze zdalnego urządzenia jest stosowana lokalnie tylko wtedy, gdy jej `updatedAt` jest nowszy od lokalnego, więc oczekujące zmiany lokalne nie są nadpisywane starszymi danymi. Brakujące kategorie własne są tworzone po nazwie na podstawie pól `categoryName`, `categorySymbol` i `categoryColor`.

Bezpieczeństwo: każdy zalogowany anonimowo użytkownik, który zna kod, ma dostęp do listy. Nie da się wylistować list ani niczego usunąć. Dane list zakupów są przechowywane na serwerach Google (Firebase), co należy uwzględnić przed ich użyciem.

## Znane ograniczenia

- Brak powiadomień push (wymagają płatnego konta dewelopera). Zmiany z chmury docierają, gdy aplikacja jest otwarta lub wraca na pierwszy plan.
- Jednoczesne dodanie produktu o tej samej nazwie przez dwie osoby tworzy dwie pozycje. Duplikat usuwa się ręcznie.
- Zmiana nazwy lub koloru istniejącej kategorii nie jest synchronizowana między telefonami. Synchronizowana jest kategoria produktu.
- Konflikty rozstrzyga czas z zegara urządzenia.
- Podpis przy darmowym koncie Apple wygasa po 7 dniach i wymaga odnawiania.
- Wersja instalowana przez AltStore ma osobną bazę od wersji z Xcode.

## Licencja

Informacje o licencji znajdują się w pliku `LICENSE`.
