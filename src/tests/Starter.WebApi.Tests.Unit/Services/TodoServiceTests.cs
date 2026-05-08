using FluentAssertions;
using Moq;
using Starter.Data.Entities;
using Starter.Data.Services;
using Starter.Shared.Contracts;
using Starter.Shared.Exceptions;

namespace Starter.WebApi.Tests.Unit.Services;

public class TodoServiceTests
{
    private readonly Mock<IRepository<TodoItem>> _repositoryMock;
    private readonly TodoService _sut;

    public TodoServiceTests()
    {
        _repositoryMock = new Mock<IRepository<TodoItem>>();
        _sut = new TodoService(_repositoryMock.Object);
    }

    [Fact]
    public async Task GetByIdAsync_WhenItemExists_ReturnsDto()
    {
        // Arrange
        var item = new TodoItem
        {
            Id = 1,
            Title = "Test Todo",
            IsComplete = false,
            CreatedAt = DateTime.UtcNow
        };
        _repositoryMock.Setup(r => r.GetByIdAsync(1, It.IsAny<CancellationToken>()))
            .ReturnsAsync(item);

        // Act
        var result = await _sut.GetByIdAsync(1);

        // Assert
        result.Should().NotBeNull();
        result!.Id.Should().Be(1);
        result.Title.Should().Be("Test Todo");
        result.IsComplete.Should().BeFalse();
    }

    [Fact]
    public async Task GetByIdAsync_WhenItemNotFound_ReturnsNull()
    {
        // Arrange
        _repositoryMock.Setup(r => r.GetByIdAsync(99, It.IsAny<CancellationToken>()))
            .ReturnsAsync((TodoItem?)null);

        // Act
        var result = await _sut.GetByIdAsync(99);

        // Assert
        result.Should().BeNull();
    }

    [Fact]
    public async Task GetAllAsync_ReturnsAllItems()
    {
        // Arrange
        var items = new List<TodoItem>
        {
            new() { Id = 1, Title = "First", IsComplete = false, CreatedAt = DateTime.UtcNow },
            new() { Id = 2, Title = "Second", IsComplete = true, CreatedAt = DateTime.UtcNow }
        };
        _repositoryMock.Setup(r => r.GetAllAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync(items);

        // Act
        var result = await _sut.GetAllAsync();

        // Assert
        result.Should().HaveCount(2);
    }

    [Fact]
    public async Task CreateAsync_CreatesAndReturnsDto()
    {
        // Arrange
        _repositoryMock.Setup(r => r.AddAsync(It.IsAny<TodoItem>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((TodoItem entity, CancellationToken _) =>
            {
                entity.Id = 1;
                return entity;
            });

        // Act
        var result = await _sut.CreateAsync("New Todo");

        // Assert
        result.Title.Should().Be("New Todo");
        result.IsComplete.Should().BeFalse();
        _repositoryMock.Verify(r => r.AddAsync(It.IsAny<TodoItem>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task UpdateAsync_WhenItemExists_UpdatesAndReturnsDto()
    {
        // Arrange
        var existingItem = new TodoItem
        {
            Id = 1,
            Title = "Original",
            IsComplete = false,
            CreatedAt = DateTime.UtcNow
        };
        _repositoryMock.Setup(r => r.GetByIdAsync(1, It.IsAny<CancellationToken>()))
            .ReturnsAsync(existingItem);
        _repositoryMock.Setup(r => r.UpdateAsync(It.IsAny<TodoItem>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        // Act
        var result = await _sut.UpdateAsync(1, "Updated", true);

        // Assert
        result.Should().NotBeNull();
        result!.Title.Should().Be("Updated");
        result.IsComplete.Should().BeTrue();
    }

    [Fact]
    public async Task UpdateAsync_WhenItemNotFound_ThrowsNotFoundException()
    {
        // Arrange
        _repositoryMock.Setup(r => r.GetByIdAsync(99, It.IsAny<CancellationToken>()))
            .ReturnsAsync((TodoItem?)null);

        // Act
        var act = () => _sut.UpdateAsync(99, "x", false);

        // Assert
        await act.Should().ThrowAsync<NotFoundException>();
    }

    [Fact]
    public async Task DeleteAsync_WhenItemExists_ReturnsTrue()
    {
        // Arrange
        var existingItem = new TodoItem
        {
            Id = 1,
            Title = "To Delete",
            IsComplete = false,
            CreatedAt = DateTime.UtcNow
        };
        _repositoryMock.Setup(r => r.GetByIdAsync(1, It.IsAny<CancellationToken>()))
            .ReturnsAsync(existingItem);
        _repositoryMock.Setup(r => r.DeleteAsync(It.IsAny<TodoItem>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        // Act
        var result = await _sut.DeleteAsync(1);

        // Assert
        result.Should().BeTrue();
        _repositoryMock.Verify(r => r.DeleteAsync(It.IsAny<TodoItem>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task DeleteAsync_WhenItemNotFound_ReturnsFalse()
    {
        // Arrange
        _repositoryMock.Setup(r => r.GetByIdAsync(99, It.IsAny<CancellationToken>()))
            .ReturnsAsync((TodoItem?)null);

        // Act
        var result = await _sut.DeleteAsync(99);

        // Assert
        result.Should().BeFalse();
    }
}
