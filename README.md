# Upload to Money Forward

Uploads expenses and incomes to Money Forward.

## Requirements

- Ruby 2.3 or later

## Usage

1.  Install gems.

    ```sh
    bundle install
    ```

2.  Prepare csv with the following header.

    ```
    "計算対象","日付","内容","金額（円）","保有金融機関","大項目","中項目","メモ","振替","ID"
    ```

3.  Run command

    ```sh
    ./moneyforward.thor username password path
    ```

## Author

naoigcat

## License

MIT
