############### Creating a domain for the preview env #########################

data "aws_route53_zone" "zone" {
  name         = "tahara.sa"
}

resource "aws_route53_record" "preview-backend-domain" {
  zone_id = data.aws_route53_zone.zone.id
  name    = "preview-dashboard.tahara.sa"
  type    = "CNAME"
  ttl     = 60
  records = [aws_lb.alp.dns_name]
  depends_on = [aws_lb.alp]
}


resource "aws_route53_record" "preview-frontend-domain" {
  zone_id = data.aws_route53_zone.zone.id
  name    = "preview-app.tahara.sa"
  type    = "CNAME"
  ttl     = 60
  records = [aws_lb.alp.dns_name]
  depends_on = [aws_lb.alp]
}
###############################################################################