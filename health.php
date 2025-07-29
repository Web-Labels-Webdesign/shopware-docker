<?php
// Simple health check script for Shopware
header('Content-Type: application/json');

try {
	// Check if we can access the basic application structure
	if (!file_exists('/var/www/html/install.lock')) {
		http_response_code(503);
		echo json_encode(['status' => 'error', 'message' => 'Installation not complete']);
		exit;
	}

	// Basic response for health check
	echo json_encode([
		'status' => 'ok',
		'message' => 'Shopware is running',
		'timestamp' => date('c')
	]);
} catch (Exception $e) {
	http_response_code(503);
	echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
}
