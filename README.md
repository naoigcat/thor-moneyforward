# Upload to Money Forward

Uploads expenses and incomes to Money Forward.

## Requirements

-   Docker

## Usage

1.  Prepare csv with the following header in the root of the project directory.

    ```csv
    "計算対象","日付","内容","金額（円）","保有金融機関","大項目","中項目","メモ","振替","ID"
    ```

2.  Run command.

    ```sh
    docker-compose build
    docker-compose run --rm app download
    docker-compose run --rm app upload
    docker-compose down
    ```

## Development

1.  Run command to start a container.

    ```sh
    docker-compose build
    docker-compose run --rm --entrypoint /bin/bash app
    ```

2.  Edit docker-entrypoint.thor.

3.  Run command to stop the container.

    ```sh
    docker-compose down
    ```

## Author

naoigcat

## License

MIT
