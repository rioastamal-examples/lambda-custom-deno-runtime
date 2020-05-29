# About

Repository ini berisi script untuk membangun custom runtime untuk Deno pada AWS Lambda. Custom runtime pada AWS Lambda dinamakan Lambda Layer. Terdapat Terraform HCL script untuk memudahkan pembuatan semua _resources_ yang dibutuhkan. Terdapat pula Typescript sebagai demo ketika menjalankan custom runtime ini.

Untuk panduan lengkap silahkan merujuk pada artikel TeknoCerdas.com berikut.

- [Tutorial Serverless: Membuat AWS Lambda Custom Runtime untuk Deno](https://teknocerdas.com/programming/tutorial-serverless-membuat-deno-runtime-untuk-aws-lambda/)

## How to Run

Pastikan anda memiliki AWS account dengan privilege Administrator agar tidak terjadi masalah ketika menjalankan Terraform.

```
$ export AWS_PROFILE=YOUR_PROFILE AWS_DEFAULT_REGION=YOUR_REGION
```

Lakukan inisialisasi dan apply untuk membuat semua resources.

```
$ bash build.sh
$ terraform init
$ terraform apply

...
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

deno_api = {
  "end_point" = "POST https://RANDOM.execute-api.us-east-1.amazonaws.com/words"
}
```

## License

Repository ini dilensiskan dibawah naungan [MIT License](https://opensource.org/licenses/MIT).
