package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"

	"github.com/promex04/pody/server/api-gateway/internal/config"
	"github.com/promex04/pody/server/api-gateway/internal/httpserver"
)

// main là hàm khởi chạy chính của API Gateway.
// Thực hiện: tải cấu hình, khởi tạo logger, chạy server và xử lý graceful shutdown.
func main() {
	// Khởi tạo logger ghi log ra màn hình console (Stdout) với định dạng text
	logger := slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))

	// Tải các thông số cấu hình từ biến môi trường (Environment Variables)
	cfg, err := config.Load()
	if err != nil {
		logger.Error("failed to load configuration", "error", err)
		os.Exit(1)
	}

	// Khởi tạo HTTP Server cho Gateway dựa trên cấu hình và logger đã tạo
	server := httpserver.New(cfg, logger)

	// Lắng nghe các tín hiệu ngắt hệ thống (SIGINT, SIGTERM) để tắt server một cách an toàn (graceful)
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	errCh := make(chan error, 1)
	go func() {
		logger.Info("starting api gateway", "addr", server.Addr)
		// Bắt đầu lắng nghe và phục vụ các kết nối HTTP
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			errCh <- err
		}
		close(errCh)
	}()

	// Chờ đợi tín hiệu tắt hoặc lỗi phát sinh trong quá trình chạy server
	select {
	case err := <-errCh:
		if err != nil {
			logger.Error("api gateway stopped unexpectedly", "error", err)
			os.Exit(1)
		}
	case <-ctx.Done():
		logger.Info("shutdown signal received")
	}

	// Thiết lập thời hạn (timeout) để hoàn thành các request đang xử lý dở dang trước khi tắt hẳn
	shutdownCtx, cancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
	defer cancel()

	// Tiến hành shutdown server graceful
	if err := server.Shutdown(shutdownCtx); err != nil {
		logger.Error("graceful shutdown failed", "error", err)
		os.Exit(1)
	}

	logger.Info("api gateway stopped")
}

