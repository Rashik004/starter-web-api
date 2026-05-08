using FluentValidation;
using Starter.WebApi.Models;

namespace Starter.WebApi.Validators;

public sealed class UpdateTodoV2RequestValidator : AbstractValidator<UpdateTodoV2Request>
{
    private static readonly string[] ValidPriorities = ["Low", "Medium", "High"];

    public UpdateTodoV2RequestValidator()
    {
        RuleFor(x => x.Title)
            .NotEmpty().WithMessage("Title is required")
            .MaximumLength(200).WithMessage("Title must not exceed 200 characters");

        RuleFor(x => x.Priority)
            .NotEmpty().WithMessage("Priority is required")
            .Must(p => ValidPriorities.Contains(p, StringComparer.OrdinalIgnoreCase))
            .WithMessage("Priority must be Low, Medium, or High");

        RuleFor(x => x.Tags)
            .MaximumLength(500).WithMessage("Tags must not exceed 500 characters")
            .When(x => x.Tags is not null);
    }
}
