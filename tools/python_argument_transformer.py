from __future__ import annotations

import libcst as cst


class PythonArgumentTransformer(cst.CSTTransformer):
    """Add magic trailing commas without changing expressions or comments."""

    def visit_FormattedString(
        self,
        node: cst.FormattedString,
    ) -> bool:
        # Python 3.11 cannot freely wrap expressions inside f-string literals.
        return False

    def leave_Call(
        self,
        original_node: cst.Call,
        updated_node: cst.Call,
    ) -> cst.Call:
        if not updated_node.args:
            return updated_node
        arguments = list(
            updated_node.args,
        )
        last = arguments[-1]
        value = last.value
        if (
            isinstance(
                value,
                cst.GeneratorExp,
            )
            and not value.lpar
        ):
            # call(x for x in items,) is invalid; keep it a generator argument.
            value = value.with_changes(
                lpar=[cst.LeftParen()],
                rpar=[cst.RightParen()],
            )
        comma = (
            last.comma
            if isinstance(
                last.comma,
                cst.Comma,
            )
            else cst.Comma()
        )
        arguments[-1] = last.with_changes(
            value=value,
            comma=comma,
        )
        return updated_node.with_changes(
            args=arguments,
        )

    def leave_FunctionDef(
        self,
        original_node: cst.FunctionDef,
        updated_node: cst.FunctionDef,
    ) -> cst.FunctionDef:
        parameters = updated_node.params
        if parameters.star_kwarg is not None:
            last = parameters.star_kwarg
            parameters = parameters.with_changes(
                star_kwarg=self._with_comma(
                    last,
                ),
            )
        elif parameters.kwonly_params:
            values = list(
                parameters.kwonly_params,
            )
            values[-1] = self._with_comma(
                values[-1],
            )
            parameters = parameters.with_changes(
                kwonly_params=values,
            )
        elif isinstance(
            parameters.star_arg,
            cst.Param,
        ):
            parameters = parameters.with_changes(
                star_arg=self._with_comma(
                    parameters.star_arg,
                ),
            )
        elif parameters.params:
            values = list(
                parameters.params,
            )
            values[-1] = self._with_comma(
                values[-1],
            )
            parameters = parameters.with_changes(
                params=values,
            )
        elif parameters.posonly_params:
            slash = parameters.posonly_ind
            if not isinstance(
                slash,
                cst.ParamSlash,
            ):
                slash = cst.ParamSlash()
            comma = (
                slash.comma
                if isinstance(
                    slash.comma,
                    cst.Comma,
                )
                else cst.Comma()
            )
            parameters = parameters.with_changes(
                posonly_ind=slash.with_changes(
                    comma=comma,
                ),
            )
        return updated_node.with_changes(
            params=parameters,
        )

    @staticmethod
    def _with_comma(
        parameter: cst.Param,
    ) -> cst.Param:
        if isinstance(
            parameter.comma,
            cst.Comma,
        ):
            return parameter
        return parameter.with_changes(
            comma=cst.Comma(),
        )
