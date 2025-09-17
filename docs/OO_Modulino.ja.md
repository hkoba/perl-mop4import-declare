# OO Modulino パターン

## 概要

OO Modulino (Object-Oriented Modulino) は、単一の Perl ファイルが「クラスモジュール」と「CLI実行可能ファイル」の両方として機能するパターンです。このパターンにより、モジュールの任意のメソッドを外部スクリプトを書くことなく CLI から直接テスト・実行できます。

## Modulino とは

Modulino は、Perl ファイルがモジュールとしても実行可能ファイルとしても動作するパターンです（[参考資料](https://www.masteringperl.org/category/chapters/modulinos/)）。

通常の Modulino では、どの関数を CLI から使えるかは実装依存です。任意の関数を使うには、結局スクリプトを書く必要があることが多くあります。

## OO Modulino の特徴

OO Modulino は Modulino を拡張し、CLI の振る舞いを標準化します：

1. **オブジェクト指向**: インスタンスを作成してメソッドを呼び出す
2. **標準化された CLI**: git コマンドのようなサブコマンド形式
3. **柔軟なパラメータ渡し**: コンストラクタオプションとメソッド引数の分離

## 基本的な実装例

### シンプルな例

```perl
package Greetings;
use strict;
use warnings;

sub new  { my $class = shift; bless +{@_}, $class }

sub hello { my $self = shift; join " ", "Hello", $self->{name} }

sub goodnight { my $self = shift; join(" ", "Good night" => $self->{name}, @_) }

1;
```

このモジュールを CLI から使うには通常：

```bash
$ perl -I. -MGreetings -le 'print Greetings->new(name => "world")->hello'
```

### 最小限の OO Modulino

```perl
#!/usr/bin/env perl
package Greetings_oo_modulino;
use strict;
use warnings;

unless (caller) {
    my $self = __PACKAGE__;

    my $cmd = shift
      or die "Usage: $0 COMMAND ARGS...\n";

    print $self->new(name => "world")->$cmd(@ARGV), "\n";
}

sub new  { my $class = shift; bless +{@_}, $class }

sub hello { my $self = shift; join " ", "Hello", $self->{name} }

sub goodnight { my $self = shift; join(" ", "Good night" => $self->{name}, @_) }

1;
```

実行例：

```bash
$ ./Greetings_oo_modulino.pm hello
Hello world
```

### コンストラクタオプション対応版

```perl
#!/usr/bin/env perl
package Greetings_with_options;
use strict;
use warnings;
use fields qw/name/;

sub MY () {__PACKAGE__}

unless (caller) {
    my $self = MY->new(name => 'world', MY->_parse_posix_opts(\@ARGV));

    my $cmd = shift @ARGV
      or die "Usage: $0 [OPTIONS] COMMAND ARGS...\n";

    print $self->$cmd(@ARGV), "\n";
}

sub _parse_posix_opts {
    my ($class, $list) = @_;
    my @opts;
    while (@$list and $list->[0] =~ /^--(?:(\w+)(?:=(.*))?)?\z/s) {
        shift @$list;
        last unless defined $1;
        push @opts, $1, $2 // 1;
    }
    @opts;
}

sub new  { my MY $self = fields::new(shift); %$self = @_; $self }

sub hello { my MY $self = shift; join " ", "Hello", $self->{name} }

sub goodnight { my MY $self = shift; join " ", "Good night" => $self->{name}, @_ }

1;
```

実行例：

```bash
$ ./Greetings_with_options.pm --name=Universe hello
Hello Universe

$ ./Greetings_with_options.pm --name=World goodnight everyone
Good night World everyone
```

## CLI の標準化

OO Modulino は以下の規約で CLI を標準化します：

### コマンドライン形式

```
program [GLOBAL_OPTIONS] COMMAND [COMMAND_ARGS]
```

- `GLOBAL_OPTIONS`: コンストラクタに渡される（`--key=value` 形式）
- `COMMAND`: 呼び出すメソッド名
- `COMMAND_ARGS`: メソッドへの引数

### git コマンドとの類似性

この設計は git コマンドに着想を得ています：

- `git --git-dir=/path commit -m "message"`
  - `--git-dir=/path`: グローバルオプション（git オブジェクトの設定）
  - `commit`: サブコマンド（メソッド）
  - `-m "message"`: コマンド引数

同様に OO Modulino では：

- `./MyScript.pm --config=prod query "SELECT * FROM users"`
  - `--config=prod`: コンストラクタオプション
  - `query`: メソッド名
  - `"SELECT * FROM users"`: メソッド引数

## fields による型安全性

`fields` プラグマを使うことで：

1. **コンパイル時の型チェック**: フィールド名のタイポを防ぐ
2. **不正なフィールドの拒否**: 未定義のフィールドへのアクセスをエラーに

```perl
use fields qw/name age/;

sub new {
    my MY $self = fields::new(shift);
    %$self = @_;
    $self;
}

sub greet {
    my MY $self = shift;
    # $self->{nama} はコンパイル時エラー（タイポ検出）
    return "I'm $self->{name}, $self->{age} years old";
}
```

## MOP4Import::Base::CLI_JSON による拡張

CLI_JSON は OO Modulino パターンを以下の点で拡張します：

1. **JSON による引数・戻り値**: 複雑なデータ構造の受け渡し
2. **自動シリアライズ**: 戻り値の自動的な JSON 出力
3. **豊富な出力形式**: ndjson, json, yaml, tsv, dump
4. **ヘルプ機能**: 自動的なヘルプメッセージ生成
5. **メソッドの自動公開**: 特別な設定なしに全パブリックメソッドが利用可能

## まとめ

OO Modulino パターンは、Perl モジュール開発において以下の利点を提供します：

- **即座のフィードバック**: メソッドを書いたらすぐ試せる
- **統一されたインターフェース**: 一貫した CLI 規約
- **テスタビリティの向上**: 小さな単位でのテストが容易
- **デバッグの容易さ**: 標準ツールがそのまま使える

これにより、開発の初期段階から本番運用まで、一貫した方法でモジュールを扱えます。

## 参考資料

- [Modulino: both script and module](https://perlmaven.com/modulino-both-script-and-module)
- [Mastering Perl: Modulinos](https://www.masteringperl.org/category/chapters/modulinos/)
- [MOP4Import::Base::CLI_JSON](../Base/CLI_JSON.pod)