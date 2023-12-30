###################### Creating Target groups #############################


resource "aws_lb_target_group" "preview-backend" {
  name        = "preview-backend"
  port        = 443
  protocol    = "HTTPS"
  target_type = "ip"
  vpc_id      = data.aws_vpcs.vpcs.ids[0]
  depends_on = [aws_lb.alp]
  health_check {
      path = "/api/check-server"
      protocol = "HTTPS"
      port = "443"
  }
}



resource "aws_lb_target_group" "preview-frontend" {
  name        = "preview-frontend"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.aws_vpcs.vpcs.ids[0]
  depends_on = [aws_lb.alp]
  health_check {
    path = "/health-check"
    protocol = "HTTP"
    port = "3000"
  }
}
##############################################################################################
##################################### Importing ACM certificate ##############################

resource "aws_acm_certificate" "preview-cert" {
  private_key = "${file("./certs/preview-cert/preview-dashboard.tahara.sa/privkey.pem")}"
  certificate_body = "${file("./certs/preview-cert/preview-dashboard.tahara.sa/cert.pem")}"
  certificate_chain = "${file("./certs/preview-cert/preview-dashboard.tahara.sa/fullchain.pem")}"
}
##############################################################################################
##################################### Create Listeners for LPs ###############################

resource "aws_lb_listener" "preview-backend" {
  load_balancer_arn = aws_lb.alp.arn
  port              = "8443"
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.preview-cert.arn
  #alpn_policy       = "HTTP2Preferred"


  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.preview-backend.arn
  }
  tags = {
    Env = "preview"
    service = "backend"
  }
  depends_on = [aws_lb.alp,aws_lb_target_group.preview-backend]
}

resource "aws_lb_listener" "preview-frontend" {
  load_balancer_arn = aws_lb.alp.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.preview-cert.arn
  #alpn_policy       = "HTTP2Preferred"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.preview-frontend.arn
  }
  tags = {
    Env = "preview"
    service = "frontend"
  }
  depends_on = [aws_lb.alp,aws_lb_target_group.preview-frontend]
}
##############################################################################################
################################### Redirection listeners ####################################
resource "aws_lb_listener" "preview-frontend-redirect" {
  load_balancer_arn = aws_lb.alp.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    target_group_arn = aws_lb_target_group.preview-frontend.arn

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
  tags = {
    Env = "preview"
    service = "frontend"
  }
}



resource "aws_lb_listener" "preview-backend-redirect" {
  load_balancer_arn = aws_lb.alp.arn
  port              = "8080"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    target_group_arn = aws_lb_target_group.preview-backend.arn

    redirect {
      port        = "8443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
  tags = {
    Env = "preview"
    service = "backend"
  }
}
##############################################################################################