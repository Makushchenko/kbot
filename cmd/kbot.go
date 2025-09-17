/*
Copyright © 2025 NAME HERE <EMAIL ADDRESS>
*/
package cmd

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/spf13/cobra"

	"github.com/hirosassa/zerodriver"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/propagation"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.24.0"
	"go.opentelemetry.io/otel/trace"
	telebot "gopkg.in/telebot.v4"
)

var (
	// TeleToken Bot
	TeleToken = os.Getenv("TELE_TOKEN")
	// MetricsHost exporter host:port
	MetricsHost = os.Getenv("METRICS_HOST")

	// tracer is the OpenTelemetry tracer.
	tracer trace.Tracer
)

// Initialize OpenTelemetry
func initMetrics(ctx context.Context) {
	// Check if MetricsHost is set
	if MetricsHost == "" {
		log.Printf("WARNING: METRICS_HOST environment variable is not set. Metrics will not be exported.")
		return // Exit the function early
	}
	// Create a new OTLP Metric gRPC exporter with the specified endpoint and options
	// Описуємо exporter otlp grpc що посилається на змінну вказану в дужках MetricsHost.
	exporter, err := otlpmetricgrpc.New(
		ctx,
		// Це адреса на якій буде доступний Collector Metric. Також там буде вказано і порт:
		otlpmetricgrpc.WithEndpoint(MetricsHost),
		otlpmetricgrpc.WithInsecure(),
	)

	if err != nil {
		log.Printf("Failed to create exporter: %v", err)
		return
	}

	// Define the resource with attributes that are common to all metrics.
	// labels/tags/resources that are common to all metrics.
	// початковий ресурс з атрибутами за замовчуванням для всіх метрик
	resource := resource.NewWithAttributes(
		semconv.SchemaURL,
		// додамо префікс імені сервісу та версії. Це дозволить нам відокремити метрики від метрик інших сервісів
		semconv.ServiceNameKey.String(fmt.Sprintf("kbot_%s", appVersion)),
	)

	// Create a new MeterProvider with the specified resource and reader
	// MeterProvider - це інтерфейс для створення метрик.
	// Він приймає resource та опції
	mp := sdkmetric.NewMeterProvider(
		sdkmetric.WithResource(resource),
		sdkmetric.WithReader(
			// collects and exports metric data every 10 seconds.
			// наприклад збирати та експортувати метрики кожні 10 секунд
			sdkmetric.NewPeriodicReader(exporter, sdkmetric.WithInterval(10*time.Second)),
		),
	)

	// Set the global MeterProvider to the newly created MeterProvider
	otel.SetMeterProvider(mp)
	log.Printf("OpenTelemetry metrics initialized, sending to: %s", MetricsHost)
}

// Initialize OpenTelemetry tracing
func initTracing(ctx context.Context) {
	if MetricsHost == "" {
		log.Printf("WARNING: METRICS_HOST environment variable is not set. Tracing will not be exported.")
		return
	}

	exporter, err := otlptracegrpc.New(
		ctx,
		otlptracegrpc.WithEndpoint(MetricsHost),
		otlptracegrpc.WithInsecure(),
	)
	if err != nil {
		log.Printf("Failed to create trace exporter: %v", err)
		return
	}

	// Reuse the same resource you're already creating for metrics
	resource := resource.NewWithAttributes(
		semconv.SchemaURL,
		semconv.ServiceNameKey.String(fmt.Sprintf("kbot_%s", appVersion)),
	)

	tracerProvider := sdktrace.NewTracerProvider(
		sdktrace.WithResource(resource),
		sdktrace.WithBatcher(exporter),
		sdktrace.WithSampler(sdktrace.AlwaysSample()),
	)

	// Set global propagator to tracecontext (W3C)
	otel.SetTextMapPropagator(propagation.TraceContext{})
	otel.SetTracerProvider(tracerProvider)

	tracer = otel.GetTracerProvider().Tracer("kbot")
	log.Printf("OpenTelemetry tracing initialized, sending to: %s", MetricsHost)
}

func pmetrics(ctx context.Context, payload string) {
	// Get the global MeterProvider and create a new Meter with the name "kbot_counter"
	meter := otel.GetMeterProvider().Meter("kbot_counter")

	// Get or create an Int64Counter instrument with the name "kbot_<payload>"
	// Використаємо це в окремому лічильнику під кожний сигнал світлофора
	counter, _ := meter.Int64Counter(fmt.Sprintf("kbot_%s", payload))

	// Add a value of 1 to the Int64Counter
	// та збільшимо його на одиницю
	counter.Add(ctx, 1)

	// Get current span from context and add attributes if available
	span := trace.SpanFromContext(ctx)
	if span.IsRecording() {
		span.SetAttributes(semconv.ServiceNameKey.String(fmt.Sprintf("kbot_%s", appVersion)))
	}
}

// logWithTrace adds trace information to the logs
func logWithTrace(ctx context.Context, logger *zerodriver.Logger, message string, payload string) {
	span := trace.SpanFromContext(ctx)

	if span.SpanContext().IsValid() {
		// Add trace ID to log
		traceID := span.SpanContext().TraceID().String()
		logger.Info().
			Str("Payload", payload).
			Str("trace_id", traceID).
			Msg(message)
	} else {
		logger.Info().Str("Payload", payload).Msg(message)
	}
}

// kbotCmd represents the kbot command
var kbotCmd = &cobra.Command{
	Use:     "kbot",
	Aliases: []string{"start"},
	Short:   "A brief description of your command",
	Long: `A longer description that spans multiple lines and likely contains examples
and usage of using your command. For example:

Cobra is a CLI library for Go that empowers applications.
This application is a tool to generate the needed files
to quickly create a Cobra application.`,
	Run: func(cmd *cobra.Command, args []string) {

		fmt.Printf("kbot %s started ", appVersion)

		logger := zerodriver.NewProductionLogger()

		kbot, err := telebot.NewBot(telebot.Settings{
			URL:    "",
			Token:  TeleToken,
			Poller: &telebot.LongPoller{Timeout: 10 * time.Second},
		})

		if err != nil {
			logger.Fatal().Str("Error", err.Error()).Msg("Please check TELE_TOKEN")
			return
		} else {
			logger.Info().Str("Version", appVersion).Msg("kbot started")
		}

		kbot.Handle(telebot.OnText, func(m telebot.Context) error {
			// Create a new trace for each incoming message
			ctx, span := tracer.Start(context.Background(), "kbot_handle_message")
			defer span.End()

			// Add message details as span attributes
			span.SetAttributes(
				semconv.MessagingSystemKey.String("telegram"),
				semconv.MessagingOperationKey.String("process"),
			)

			payload := m.Message().Payload

			// Use the trace context for metrics
			pmetrics(ctx, payload)

			// Use the trace context for logging
			logWithTrace(ctx, logger, m.Text(), payload)

			switch payload {
			case "hello":
				_, childSpan := tracer.Start(ctx, "send_hello_response")
				err = m.Send(fmt.Sprintf("Hello I'm Kbot %s!", appVersion))
				childSpan.End()
			}

			return err
		})

		kbot.Start()
	},
}

func init() {
	ctx := context.Background()
	initMetrics(ctx)
	initTracing(ctx) // Add this line
	rootCmd.AddCommand(kbotCmd)

	// Here you will define your flags and configuration settings.

	// Cobra supports Persistent Flags which will work for this command
	// and all subcommands, e.g.:
	// kbotCmd.PersistentFlags().String("foo", "", "A help for foo")

	// Cobra supports local flags which will only run when this command
	// is called directly, e.g.:
	// kbotCmd.Flags().BoolP("toggle", "t", false, "Help message for toggle")
}
