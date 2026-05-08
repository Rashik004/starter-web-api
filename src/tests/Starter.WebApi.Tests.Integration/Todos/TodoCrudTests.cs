using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using FluentAssertions;

namespace Starter.WebApi.Tests.Integration.Todos;

public class TodoCrudTests(CustomWebApplicationFactory factory)
    : IClassFixture<CustomWebApplicationFactory>
{
    private readonly HttpClient _client = factory.CreateClient();

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true
    };

    [Fact]
    public async Task GetAll_ReturnsOkWithList()
    {
        var response = await _client.GetAsync("/api/v1/todos");

        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Create_WithValidTitle_ReturnsCreated()
    {
        var response = await _client.PostAsJsonAsync(
            "/api/v1/todos", new { Title = "Integration Test Todo" });

        response.StatusCode.Should().Be(HttpStatusCode.Created);

        var content = await response.Content.ReadAsStringAsync();
        var json = JsonDocument.Parse(content).RootElement;

        // Response is wrapped in ApiResponse envelope: { success, data, timestamp }
        json.GetProperty("success").GetBoolean().Should().BeTrue();

        var data = json.GetProperty("data");
        data.GetProperty("id").GetInt32().Should().BeGreaterThan(0);
        data.GetProperty("title").GetString().Should().Be("Integration Test Todo");
    }

    [Fact]
    public async Task GetById_AfterCreate_ReturnsOk()
    {
        // Create a todo first
        var createResponse = await _client.PostAsJsonAsync(
            "/api/v1/todos", new { Title = "Get By Id Test" });
        createResponse.EnsureSuccessStatusCode();

        var createContent = await createResponse.Content.ReadAsStringAsync();
        var createJson = JsonDocument.Parse(createContent).RootElement;
        var id = createJson.GetProperty("data").GetProperty("id").GetInt32();

        // Get by id
        var response = await _client.GetAsync($"/api/v1/todos/{id}");

        response.StatusCode.Should().Be(HttpStatusCode.OK);

        var content = await response.Content.ReadAsStringAsync();
        var json = JsonDocument.Parse(content).RootElement;

        json.GetProperty("data").GetProperty("title").GetString()
            .Should().Be("Get By Id Test");
    }

    [Fact]
    public async Task Update_ExistingItem_ReturnsOk()
    {
        // Create a todo first
        var createResponse = await _client.PostAsJsonAsync(
            "/api/v1/todos", new { Title = "Before Update" });
        createResponse.EnsureSuccessStatusCode();

        var createContent = await createResponse.Content.ReadAsStringAsync();
        var createJson = JsonDocument.Parse(createContent).RootElement;
        var id = createJson.GetProperty("data").GetProperty("id").GetInt32();

        // Update it
        var response = await _client.PutAsJsonAsync(
            $"/api/v1/todos/{id}", new { Title = "Updated Todo", IsComplete = true });

        response.StatusCode.Should().Be(HttpStatusCode.OK);

        var content = await response.Content.ReadAsStringAsync();
        var json = JsonDocument.Parse(content).RootElement;

        var data = json.GetProperty("data");
        data.GetProperty("title").GetString().Should().Be("Updated Todo");
        data.GetProperty("isComplete").GetBoolean().Should().BeTrue();
    }

    [Fact]
    public async Task Delete_ExistingItem_ReturnsNoContent()
    {
        // Create a todo first
        var createResponse = await _client.PostAsJsonAsync(
            "/api/v1/todos", new { Title = "To Be Deleted" });
        createResponse.EnsureSuccessStatusCode();

        var createContent = await createResponse.Content.ReadAsStringAsync();
        var createJson = JsonDocument.Parse(createContent).RootElement;
        var id = createJson.GetProperty("data").GetProperty("id").GetInt32();

        // Delete it
        var response = await _client.DeleteAsync($"/api/v1/todos/{id}");

        response.StatusCode.Should().Be(HttpStatusCode.NoContent);
    }

    [Fact]
    public async Task GetById_NonExistent_ReturnsNotFound()
    {
        var response = await _client.GetAsync("/api/v1/todos/99999");

        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task Delete_NonExistent_ReturnsNotFound()
    {
        var response = await _client.DeleteAsync("/api/v1/todos/99999");

        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }
}
