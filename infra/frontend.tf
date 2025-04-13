# create bucket
resource "aws_s3_bucket" "site_bucket" {
  bucket = "bucket-crc-znr"
}

# enable block public access
resource "aws_s3_bucket_public_access_block" "block_public" {
  bucket = aws_s3_bucket.site_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# upload html file (all upload resources disabled, change using aws s3 sync)
# resource "aws_s3_object" "index_html" {
#   bucket       = aws_s3_bucket.site_bucket.id
#   key          = "index.html"
#   source       = "../../static-site/index.html"
#   content_type = "text/html"
# }

# upload css file
# resource "aws_s3_object" "style_css" {
#   bucket       = aws_s3_bucket.site_bucket.id
#   key          = "style.css"
#   source       = "../../static-site/style.css"
#   content_type = "text/css"
# }

# upload js file
# resource "aws_s3_object" "script_js" {
#   bucket       = aws_s3_bucket.site_bucket.id
#   key          = "script.js"
#   source       = "../../static-site/script.js"
#   content_type = "application/javascript"
# }

# upload all images
# resource "aws_s3_object" "upload_all_images" {
#   bucket       = aws_s3_bucket.site_bucket.id
#   for_each     = fileset("../../static-site/img", "*")
#   key          = "img/${each.value}"
#   source       = "../../static-site/img/${each.value}"
#   content_type = "image/jpeg"
# }

# create OAC resource to securely access S3 bucket
resource "aws_cloudfront_origin_access_control" "oac_s3" {
  name                              = aws_s3_bucket.site_bucket.bucket_regional_domain_name
  description                       = "For cloudfront OAC with S3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# get SSL/TLS certificate data for domain from AWS ACM
data "aws_acm_certificate" "issued" {
  domain   = "*.zaril.my.id"
  statuses = ["ISSUED"]
}

# define local value for S3 origin
locals {
  s3_origin_id = "crc-S3-Origin"
}

# create cloudfront distribution
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.site_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.oac_s3.id
    origin_id                = local.s3_origin_id
  }

  enabled             = true
  is_ipv6_enabled     = false
  default_root_object = "index.html"

  aliases = ["cv.zaril.my.id"]
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 1
    default_ttl            = 86400
    max_ttl                = 31536000
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.issued.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

# create and attach policy for S3 bucket that allows cloudfront to access 
resource "aws_s3_bucket_policy" "allow_access_cloudfront_to_s3" {
  bucket = aws_s3_bucket.site_bucket.id
  policy = jsonencode({
    "Version" : "2008-10-17",
    "Id" : "PolicyForCloudFrontPrivateContent",
    "Statement" : [
      {
        "Sid" : "AllowCloudFrontServicePrincipal",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "cloudfront.amazonaws.com"
        },
        "Action" : "s3:GetObject",
        "Resource" : "arn:aws:s3:::${aws_s3_bucket.site_bucket.id}/*",
        "Condition" : {
          "StringEquals" : {
            "AWS:SourceArn" : "${aws_cloudfront_distribution.s3_distribution.arn}"
          }
        }
      }
    ]
  })
}

# show cloudfont distribution url
output "distribution_url" {
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}