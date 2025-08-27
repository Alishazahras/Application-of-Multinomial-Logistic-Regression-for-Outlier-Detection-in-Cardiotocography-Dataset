library(nnet)   # Untuk regresi logistik multinomial
library(car)    # Untuk uji multikolinearitas
library(readxl)
CTG_dataset <- read_excel("C:/BINUS FILE/Assignment/Sem. 7/Research Methodology in Computer Science/CTG_dataset.xlsx")
# Load file Excel
data = CTG_dataset
head(data)
View(data)
str(data)

library(ggplot2)
# Membuat countplot
# Membuat countplot dengan warna per kategori
ggplot(data, aes(x = NSP, fill = as.factor(NSP))) +
  geom_bar(color = "black") +
  geom_text(stat = 'count', aes(label = ..count..), vjust = -0.5) +
  scale_fill_manual(values = c("1" = "red", "2" = "blue", "3" = "green")) + # Warna kustom
  labs(title = "Countplot NSP",
       x = "Label",
       y = "Frekuensi",
       fill = "Label") +
  theme_minimal()

# Membuat model regresi linier sebagai dasar untuk menguji multikolinearitas
model_lm <- lm(NSP ~ LB + data$AC...3 + data$FM...4 + data$UC...5 + data$DL...6 + data$DS...7 + data$DP...8 + ASTV + MSTV + ALTV + MLTV + Width, data = data)
summary(model_lm)

# Uji multikolinearitas menggunakan VIF
vif_values <- vif(model_lm)

# Menampilkan nilai VIF
vif_values

# Sebagai aturan umum, nilai VIF > 5 atau 10 menunjukkan adanya multikolinearitas tinggi

# Fit model regresi logistik multinomial
model_multinom <- multinom(NSP ~ LB + data$AC...3 + data$FM...4 + data$UC...5 + data$DL...6 + data$DS...7 + data$DP...8 + ASTV + MSTV + ALTV + MLTV + Width, data = data)

# Menampilkan ringkasan model untuk melihat p-value dan koefisien
summary(model_multinom)

summ_coef = as.data.frame(coef(summary(model_multinom)))
summ_coef

odds_calc <- function(x){
  if(x < 0){
    return(1 - exp(x))
  }else{
    return(exp(x))
  }
}

odds_res <- as.data.frame(apply(summ_coef, c(1, 2), odds_calc))
odds_res

# LRT
library(lmtest)
modelmultinom_null = multinom(NSP ~ 1, data=data)
lrtest(model_multinom, modelmultinom_null)

# Parsial-Wald Test
z = summary(model_multinom)$coefficients/summary(model_multinom)$standard.errors
p = 2 * (1 - pnorm(abs(z), 0, 1))
data.frame(p)

library(car)
car::Anova(model_multinom, model ="LR")

model_signmultinom <- multinom(NSP ~ LB + data$AC...3 + data$FM...4 + data$UC...5 + data$DL...6 + 
                                 data$DS...7 + data$DP...8 + ASTV + MSTV + ALTV + MLTV + Width, data = data)
summary(model_signmultinom)

# Parsial-Wald Test
z = summary(model_signmultinom)$coefficients/summary(model_signmultinom)$standard.errors
p = 2 * (1 - pnorm(abs(z), 0, 1))
data.frame(p)

# 1. Menghitung Pearson Residuals
pearson_residuals <- residuals(model_signmultinom, type = "pearson")
print("Pearson Residuals:")
head(pearson_residuals)

# 2. Menghitung Deviance Residuals
deviance_residuals <- residuals(model_signmultinom, type = "deviance")
print("Deviance Residuals:")
head(deviance_residuals)

# 3. Menghitung Cook's Distance
# Membuat matriks model dari regresi multinomial
X <- model.matrix(model_signmultinom)

# Menghitung hat values secara manual
XtX_inv <- solve(t(X) %*% X)   # Inverse dari XtX
hat_matrix <- X %*% XtX_inv %*% t(X)  # Menghitung hat matrix (H)
hat_values <- diag(hat_matrix)  # Ambil diagonalnya sebagai leverage (hat values)

# Menampilkan beberapa nilai leverage (hat values)
head(hat_values)

# Menghitung Cook's Distance
cooks_distance <- (deviance_residuals^2 * hat_values) / (ncol(X) * (1 - hat_values)^2)
print("Cook's Distance:")
head(cooks_distance)

# Mendeteksi outliers dengan Cook's Distance besar (misalnya > 4/n)
n <- nrow(data)
outliers_cooks <- which(cooks_distance > 4/n)
print("Outliers berdasarkan Cook's Distance:")
print(outliers_cooks)

# Menyimpan hasil outliers berdasarkan semua metode
outliers_all <- list(
  cooks = outliers_cooks,
  pearson = which(abs(pearson_residuals) > 2),      # Threshold contoh untuk Pearson Residuals
  deviance = which(abs(deviance_residuals) > 2)     # Threshold contoh untuk Deviance Residuals
  )
print("Outliers berdasarkan Pearson, Deviance, dan Cook's Distance:")
print(outliers_all)

hist(cooks_distance, main="Cook's Distance Distribution")
hist(pearson_residuals, main="Pearson Residuals Distribution")
hist(deviance_residuals, main="Deviance Residuals Distribution")

library(glmnet)

# Menyiapkan data
x <- model.matrix(NSP ~ LB + data$AC...3 + data$FM...4 + data$UC...5 + data$DL...6 + 
                    data$DS...7 + data$DP...8 + ASTV + MSTV + ALTV + MLTV + Width + CLASS, data = data)
y <- data$NSP

# Fit Ridge model
ridge_model <- cv.glmnet(x, y, family = "multinomial", alpha = 0)

# Ekstrak koefisien dari Ridge model pada lambda.min
coef_ridge <- predict(ridge_model, s = "lambda.min", type = "coefficients")
coef_ridge

# Prediksi probabilitas
pred_ridge <- predict(ridge_model, s = "lambda.min", newx = x, type = "response")

# Menghitung leverage (hat values) secara manual
# H = X (X'X)^(-1) X'
XtX_inv <- solve(t(x) %*% x)  # Inverse dari XtX
hat_matrix <- x %*% XtX_inv %*% t(x)  # Menghitung hat matrix
hat_values <- diag(hat_matrix)  # Ambil diagonal sebagai leverage (hat values)

# Menampilkan leverage (hat values)
head(hat_values)

# Menghitung residuals
residuals_ridge <- y - apply(pred_ridge, 1, which.max)

# Menghitung Cook's Distance
cooks_distance2 <- (residuals_ridge^2 * hat_values) / (ncol(x) * (1 - hat_values)^2)

# Menampilkan beberapa nilai Cook's Distance
head(cooks_distance2)

n <- nrow(data)
outliers_cooks2 <- which(cooks_distance2 > 4/n)
print("Outliers berdasarkan Cook's Distance:")
print(outliers_cooks2)
